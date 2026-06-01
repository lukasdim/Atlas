#pragma once
#include <QObject>
#include <QFile>
#include <QCoreApplication>
#include <QtQml/qqml.h>

// Lightweight file-I/O helper exposed to QML.
// Registered to the Atlas QML module via QML_ELEMENT — available in all
// Atlas QML files without an explicit import statement.
class FileIO : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Full path where the runtime drinks.json lives (next to the executable).
    Q_PROPERTY(QString drinksPath READ drinksPath CONSTANT)

public:
    explicit FileIO(QObject *parent = nullptr) : QObject(parent) {}

    QString drinksPath() const
    {
        return QCoreApplication::applicationDirPath() + "/drinks.json";
    }

    // Returns file contents as a string, or "" if the file cannot be read.
    Q_INVOKABLE QString read(const QString &path) const
    {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
            return {};
        return QString::fromUtf8(f.readAll());
    }

    // Writes content to path (creates or truncates). Returns true on success.
    Q_INVOKABLE bool write(const QString &path, const QString &content) const
    {
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text))
            return false;
        f.write(content.toUtf8());
        return true;
    }
};
