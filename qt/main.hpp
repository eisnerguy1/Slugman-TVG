#include <QtOpenGL>
#include <QTimer>
#include "GLGame.h"

class GLWidget : public QGLWidget
{
    Q_OBJECT

public:
    GLWidget(QWidget *parent = 0);

protected:
    void paintGL();
    void resizeGL(int width, int height);
    void keyPressEvent(QKeyEvent *);
    void keyReleaseEvent(QKeyEvent *);
    void mousePressEvent(QMouseEvent *);
    
private slots:
    void newGame();
    void pauseGame();
    void endGame();
    void showHelp();
    void showAbout();
    void showHighScores();
    void resetHighScores();
    
private:
    GL::Game game_;
    QTimer timer_;
    
    bool handleKeyEvent(int key, bool down);
};

class MainWindow : public QMainWindow
{
    Q_OBJECT
    
public:
    MainWindow();
    
private:
    GLWidget *glwid_;
    QAction *newAction_;
    QAction *pauseAction_;
    QAction *endAction_;
    QAction *helpAction_;
    QAction *scoresAction_;
    QAction *resetAction_;
    QAction *aboutAction_;
};
