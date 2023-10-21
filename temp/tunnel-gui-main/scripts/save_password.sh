SCRIPT_PATH=`readlink -f "$0"`
SCRIPTS_DIR=`dirname "$SCRIPT_PATH"`
PROJECT_DIR=`dirname "$SCRIPTS_DIR"`

rm $PROJECT_DIR/web_password.txt
echo $1 > $PROJECT_DIR/web_password.txt
