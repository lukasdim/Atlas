/* main.cpp — minimal loader for Main.qml with SIGUSR1/SIGUSR2 handlers
 * to drop/grab DRM master via Qt's own DRM fd.
 *
 * SIGUSR1 = reclaim DRM master (display on)
 * SIGUSR2 = release DRM master (display off)
 */
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QSocketNotifier>
#include <QDir>
#include <QFile>

#include <csignal>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <xf86drm.h>

#include <iostream>

#include <QEvent>
#include <QTimer>
#include <xf86drmMode.h>
#include <cstdlib>

class IdleManager : public QObject {
public:
    IdleManager(int *drmFdPtr, int idleMs, QObject *parent = nullptr)
        : QObject(parent), m_drmFd(drmFdPtr), m_displayOn(true) {
        m_timer.setSingleShot(true);
        m_timer.setInterval(idleMs);
        QObject::connect(&m_timer, &QTimer::timeout, this, [this]() {
            blankDisplay();
        });
        m_timer.start();
    }

    bool eventFilter(QObject *watched, QEvent *event) override {
        switch (event->type()) {
            case QEvent::MouseButtonPress:
            case QEvent::MouseButtonRelease:
            case QEvent::MouseMove:
            case QEvent::TouchBegin:
            case QEvent::TouchUpdate:
            case QEvent::TouchEnd:
            case QEvent::KeyPress:
            case QEvent::KeyRelease:
                if (!m_displayOn) wakeDisplay();
                m_timer.start();
                break;
            default:
                break;
        }
        return QObject::eventFilter(watched, event);
    }

private:
    void blankDisplay() {
        if (*m_drmFd < 0 || !m_displayOn) return;
        setConnectorDpms(DRM_MODE_DPMS_OFF);
        m_displayOn = false;
        std::cerr << "Idle: display OFF\n";
    }

    void wakeDisplay() {
        if (*m_drmFd < 0 || m_displayOn) return;
        setConnectorDpms(DRM_MODE_DPMS_ON);
        m_displayOn = true;
        std::cerr << "Input: display ON\n";
    }

    void setConnectorDpms(int state) {
        drmModeRes *res = drmModeGetResources(*m_drmFd);
        if (!res) return;
        for (int i = 0; i < res->count_connectors; i++) {
            drmModeConnector *c = drmModeGetConnector(*m_drmFd, res->connectors[i]);
            if (!c) continue;
            if (c->connector_type == DRM_MODE_CONNECTOR_HDMIA) {
                drmModeObjectProperties *props = drmModeObjectGetProperties(
                    *m_drmFd, c->connector_id, DRM_MODE_OBJECT_CONNECTOR);
                if (props) {
                    for (uint32_t j = 0; j < props->count_props; j++) {
                        drmModePropertyRes *p = drmModeGetProperty(*m_drmFd, props->props[j]);
                        if (p && strcmp(p->name, "DPMS") == 0) {
                            drmModeConnectorSetProperty(*m_drmFd, c->connector_id,
                                                         p->prop_id, state);
                            drmModeFreeProperty(p);
                            break;
                        }
                        if (p) drmModeFreeProperty(p);
                    }
                    drmModeFreeObjectProperties(props);
                }
                drmModeFreeConnector(c);
                break;
            }
            drmModeFreeConnector(c);
        }
        drmModeFreeResources(res);
    }

    QTimer m_timer;
    int *m_drmFd;
    bool m_displayOn;
};

static int sigPipe[2];
static int drmFd = -1;

static void signalHandler(int sig) {
    unsigned char s = static_cast<unsigned char>(sig);
    ssize_t r = write(sigPipe[1], &s, 1);
    (void)r;
}

static void handleSignal(int sig) {
    if (drmFd < 0) {
        std::cerr << "Signal " << sig << " received but no DRM fd\n";
        return;
    }
    if (sig == SIGUSR2) {
        int r = drmDropMaster(drmFd);
        std::cerr << "drmDropMaster -> " << r
                  << (r == 0 ? " (released)" : " (failed)") << "\n";
    } else if (sig == SIGUSR1) {
        int r = drmSetMaster(drmFd);
        std::cerr << "drmSetMaster -> " << r
                  << (r == 0 ? " (reclaimed)" : " (failed)") << "\n";
    }
}

/* Find Qt's already-open DRM fd by scanning /proc/self/fd/ */
static int findQtsDrmFd() {
    DIR *d = opendir("/proc/self/fd");
    if (!d) return -1;
    struct dirent *e;
    int found = -1;
    while ((e = readdir(d)) != NULL) {
        char *end;
        long fd = strtol(e->d_name, &end, 10);
        if (*end != '\0' || fd < 0) continue;
        
        char link_target[256];
        char proc_path[64];
        snprintf(proc_path, sizeof(proc_path), "/proc/self/fd/%ld", fd);
        ssize_t n = readlink(proc_path, link_target, sizeof(link_target) - 1);
        if (n <= 0) continue;
        link_target[n] = '\0';
        
        if (strncmp(link_target, "/dev/dri/card", 13) == 0) {
            found = (int)fd;
            break;
        }
    }
    closedir(d);
    return found;
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    // Set up self-pipe for signal handling.
    if (pipe(sigPipe) != 0) {
        std::cerr << "Failed to create signal pipe\n";
        return 1;
    }
    fcntl(sigPipe[0], F_SETFD, FD_CLOEXEC);
    fcntl(sigPipe[1], F_SETFD, FD_CLOEXEC);

    struct sigaction sa;
    sa.sa_handler = signalHandler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESTART;
    sigaction(SIGUSR1, &sa, nullptr);
    sigaction(SIGUSR2, &sa, nullptr);

    QSocketNotifier sigNotifier(sigPipe[0], QSocketNotifier::Read);
    QObject::connect(&sigNotifier, &QSocketNotifier::activated, [](int) {
        unsigned char s;
        if (read(sigPipe[0], &s, 1) == 1) {
            handleSignal(static_cast<int>(s));
        }
    });

    // Write PID file so external services can signal us.
    QFile pidFile("/tmp/atlas_qt.pid");
    if (pidFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        pidFile.write(QString::number(QCoreApplication::applicationPid()).toUtf8());
        pidFile.write("\n");
        pidFile.close();
    }

    // Load Main.qml from the executable's directory.
    QQmlApplicationEngine engine;
    QString qmlPath = QDir(QCoreApplication::applicationDirPath())
                          .filePath("Main.qml");
    engine.load(QUrl::fromLocalFile(qmlPath));
    if (engine.rootObjects().isEmpty()) {
        std::cerr << "Failed to load " << qmlPath.toStdString() << "\n";
        return 1;
    }

    // Now that Qt's EGLFS is up, find its DRM fd.
    drmFd = findQtsDrmFd();
    if (drmFd < 0) {
        std::cerr << "Warning: could not find Qt's DRM fd\n";
    } else {
        std::cerr << "Found Qt's DRM fd: " << drmFd << "\n";
    }
    // Read idle timeout from env var, default 300 seconds.
    int idleMs = 300000;
    const char *envIdle = std::getenv("ATLAS_IDLE_MS");
    if (envIdle) {
        int v = std::atoi(envIdle);
        if (v > 0) idleMs = v;
    }
    
    IdleManager *idleMgr = new IdleManager(&drmFd, idleMs, &app);
    app.installEventFilter(idleMgr);
    int rc = app.exec();
    // Don't close drmFd — Qt owns it
    QFile::remove("/tmp/atlas_qt.pid");
    return rc;
}
