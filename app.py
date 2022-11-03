import os
import shelve
import subprocess
from flask import Flask, render_template, redirect, url_for, request, session

from forms import StaticIpForm, PasswordForm, TunnelForm
from utils import do_change_password, change_ip

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "really-long-string")

# db = shelve.open


@app.route("/", methods=["GET", "POST"])
def index():
    """This renders IP Address template"""
    form = StaticIpForm(meta={"csrf": False})

    if request.method == "POST":
        if form.validate_on_submit():
            change_ip(ip, network, gateway, dns)
    return render_template("index.html", form=form)


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
    app.run(debug=True)
    # from waitress import serve
    # serve(app, host="0.0.0.0", port=8080)
