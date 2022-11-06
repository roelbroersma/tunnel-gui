import os
from pathlib import Path
import shelve
import subprocess

from dotenv import load_dotenv
from flask import Flask, redirect, url_for, request, session
from flask import render_template as flask_render_template

from .forms import StaticIpForm, PasswordForm, TunnelForm
from .utils import do_change_password, change_ip


BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY")

# db = shelve.open


def render_template(template_name: str, **kwargs):
    menu_items = [
        ('index', 'IP Address', 'home'),
        ('change_password', 'Password', 'speedometer2'),
        ('tunnel', 'Tunnel', 'table'),
        ('diagnostics', 'Diagnostics', 'grid'),
    ]
    active_item = template_name[:-5].replace('-', '_')
    return flask_render_template(template_name, **kwargs, menu_items=menu_items, active_item=active_item)


@app.route("/", methods=["GET", "POST"])
def index():
    """This renders IP Address template"""
    form = StaticIpForm(meta={"csrf": False})

    if request.method == "POST":
        if form.validate_on_submit():
            change_ip(ip, network, gateway, dns)
    return render_template("index.html", form=form)


@app.route("/old-change-password", methods=["GET", "POST"])
def old_change_password():
    form = PasswordForm(meta={"csrf": False})
    error = False

    if request.method == "POST":
        if form.validate_on_submit():
            new_password = form.password.data
            password_again = form.password_again.data
            print(new_password)
            print(password_again)
            # assert(new_password == password_again)
            if new_password == password_again:
                # shelve sync
                do_change_password(new_password)
            else:
                error = "Passwords didn't match"
                return render_template("old-change-password.html", form=form, error=error)
    return render_template("old-change-password.html", form=form)


@app.route("/change-password", methods=["GET", "POST"])
def change_password():
    form = PasswordForm(meta={"csrf": False})
    error = False

    if request.method == "POST":
        if form.validate_on_submit():
            new_password = form.password.data
            password_again = form.password_again.data
            print(new_password)
            print(password_again)
            # assert(new_password == password_again)
            if new_password == password_again:
                # shelve sync
                do_change_password(new_password)
            else:
                error = "Passwords didn't match"
                return render_template("change-password.html", form=form, error=error)
    return render_template("change-password.html", form=form)


@app.route("/tunnel", methods=["GET", "POST"])
def tunnel():
    form = TunnelForm()
    return render_template("tunnel.html", form=form)


@app.route("/diagnostics", methods=["GET", "POST"])
def diagnostics():
    return render_template("diagnostics.html")


if __name__ == "__main__":
    is_debug = os.getenv('DEBUG', 'False').lower() == 'true'
    app.run(debug=is_debug)
    # from waitress import serve
    # serve(app, host="0.0.0.0", port=8080)
