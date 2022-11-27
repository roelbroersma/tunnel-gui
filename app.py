import os
from pathlib import Path
import shelve
import subprocess

from dotenv import load_dotenv
from flask import Flask, redirect, url_for, request, session
from flask import render_template as flask_render_template
from pydantic import BaseModel

from forms import IpAddressChangeForm, PasswordForm, TunnelForm, SignInForm
from utils import do_change_password, change_ip, get_token, get_passwords


BASE_DIR = Path(__file__).resolve().parent
load_dotenv(BASE_DIR / ".env")

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY")

# db = shelve.open


class MenuItemInfo(BaseModel):
    linked_route_method_name: str
    svg_icon_id: str
    title: str


def render_template(route_name: str, **kwargs):
    menu_items = [
        MenuItemInfo(
            linked_route_method_name='index',
            title='IP Address',
            svg_icon_id='map_pin'
        ),
        MenuItemInfo(
            linked_route_method_name='change_password',
            title='Password',
            svg_icon_id='key'
        ),
        MenuItemInfo(
            linked_route_method_name='tunnel',
            title='Tunnel',
            svg_icon_id='route'
        ),
        MenuItemInfo(
            linked_route_method_name='diagnostics',
            title='Diagnostics',
            svg_icon_id='checklist'
        ),
        MenuItemInfo(
            linked_route_method_name='signout',
            title='Sign Out',
            svg_icon_id='exit'
        ),
    ]
    template_name = f"{route_name}.html"
    return flask_render_template(template_name, **kwargs, menu_items=menu_items, active_route_method_name=route_name)


def do_response_from_context(make_context_func):
    def wrapper(*args, **kwargs):
        user_token = request.cookies.get('userToken')
        existed_tokens = [
            get_token(password) for password in get_passwords() if password
        ]
        if user_token not in existed_tokens:
            return redirect(url_for('signin'), code=302)

        context = make_context_func(*args, **kwargs)
        route_name = make_context_func.__name__
        if 'callback' in context:
            return context['callback']()

        return render_template(route_name, **context)
    wrapper.__name__ = make_context_func.__name__
    return wrapper


@app.route("/signin", methods=["GET", "POST"])
def signin():
    form = SignInForm(request.form, meta={"csrf": False})

    if request.method == "POST":
        is_ok = form.validate_on_submit()

        if is_ok:
            raw_password = form.password.data
            response = redirect(url_for('index'), code=302)
            response.set_cookie('userToken', get_token(raw_password))
            return response
    return flask_render_template("signin.html", form=form)


@app.route("/signout", methods=["GET", ])
def signout():
    response = redirect(url_for('index'), code=302)
    response.set_cookie('userToken', '-')
    return response


@app.route("/", methods=["GET", "POST"])
@do_response_from_context
def index():
    """This renders IP Address template"""
    form = IpAddressChangeForm(request.form, meta={"csrf": False})

    if request.method == "POST":
        is_ok = form.validate_on_submit()

        if is_ok:
            form_generated_data = form.get_generated_data()
            change_ip(form_generated_data)
    return {'form': form}


@app.route("/change-password", methods=["GET", "POST"])
@do_response_from_context
def change_password():
    form = PasswordForm(request.form, meta={"csrf": False})

    if request.method == "POST":
        is_ok = form.validate_on_submit()

        if is_ok:
            # shelve sync
            do_change_password(form.pass1.data)
            return {'callback': lambda: redirect(url_for('signin'), code=302)}
    return {'form': form}


@app.route("/tunnel", methods=["GET", "POST"])
@do_response_from_context
def tunnel():
    form = TunnelForm()
    return {'form': form}


@app.route("/diagnostics", methods=["GET", "POST"])
@do_response_from_context
def diagnostics():
    return dict()


@app.route("/log-file", methods=["GET", ])
def get_log_file():
    with open(os.getenv('LOG_PATH', '/'), 'r+') as f:
        return f.readlines()


if __name__ == "__main__":
    is_debug = os.getenv('DEBUG', 'False').lower() == 'true'
    if is_debug:
        app.run(debug=is_debug, host="0.0.0.0")
    else:
        from waitress import serve
        serve(app, host="0.0.0.0", port=8080)
