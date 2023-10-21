SCRIPT_PATH="$(realpath "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")/"
BASE_DIR="${SCRIPT_DIR}../"

rm ${BASE_DIR}/web_password.txt
echo $1 > ${BASE_DIR}/web_password.txt
