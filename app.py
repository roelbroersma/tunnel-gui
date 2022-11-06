import os
from pathlib import Path
import shelve
import subprocess

from dotenv import load_dotenv
from flask import Flask, redirect, url_for, request, session
from flask import render_template as flask_render_template
from pydantic import BaseModel

from .forms import StaticIpForm, PasswordForm, TunnelForm
from .utils import do_change_password, change_ip


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
    ]
    template_name = f"{route_name}.html"
    return flask_render_template(template_name, **kwargs, menu_items=menu_items, active_route_method_name=route_name)


def do_response_from_context(make_context_func):
    def wrapper(*args, **kwargs):
        context = make_context_func(*args, **kwargs)
        route_name = make_context_func.__name__
        return render_template(route_name, **context)
    wrapper.__name__ = make_context_func.__name__
    return wrapper


@app.route("/", methods=["GET", "POST"])
@do_response_from_context
def index():
    """This renders IP Address template"""
    form = StaticIpForm(meta={"csrf": False})

    if request.method == "POST":
        if form.validate_on_submit():
            change_ip(ip, network, gateway, dns)
    return {'form': form}


@app.route("/change-password", methods=["GET", "POST"])
@do_response_from_context
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
                return {'form': form, 'error': error}
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


if __name__ == "__main__":
    is_debug = os.getenv('DEBUG', 'False').lower() == 'true'
    app.run(debug=is_debug)
    # from waitress import serve
    # serve(app, host="0.0.0.0", port=8080)
