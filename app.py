import os
import json
from pathlib import Path
import requests
import shelve
import subprocess
import uuid

from dotenv import load_dotenv
from flask import Flask, redirect, url_for, request, session
from flask import render_template as flask_render_template
from pydantic import BaseModel

from forms import IpAddressChangeForm, PasswordForm, TunnelForm, SignInForm, TunnelMasterForm, TunnelNonMasterForm
from utils import do_change_password, change_ip, get_token, get_passwords, IP_CONFIG_FILE, IpAddressChangeInfo, show_ip, PublicIpInfo, show_public_ip, save_tunnel_configuration, load_tunnel_configuration


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
        if context is not None and 'callback' in context:
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
    elif request.method == "GET":
        ip_change_info = show_ip()

        form.ip_address.default = ip_change_info.ip_address or None
        form.ip_type.default = ip_change_info.ip_type or None
        form.subnet.default = ip_change_info.subnet or None
        form.gateway.default = ip_change_info.gateway or None
        form.dns_servers.default = ip_change_info.dns_servers[0] or None
        form.process()

    fields = []
    for field_key in ['ip_address', 'subnet', 'gateway', 'dns_servers']:
        fields.append((field_key, form[field_key].label))
    return {'form': form, 'fields': fields}


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
    tunnel_master_form = TunnelMasterForm(request.form, meta={"csrf": False})
    tunnel_non_master_form = TunnelNonMasterForm(request.form, meta={"csrf": False})

    device_id = json.loads(subprocess.Popen(
        'scripts/show_machine_id.sh', stdout=subprocess.PIPE
    ).communicate()[0])["machine_id"]

    if not tunnel_master_form.is_submitted():
       config_data = load_tunnel_configuration(tunnel_master_form)
#        if config_data:
#       print(config_data)
            #LOOP THROUGH THE CONFIG_DATA AND ASSIGN IT TO THE TUNNEL_MASTER_FORM
#            for field_name, field_value in config_data.items():
#                if hasattr(tunnel_master_form, field_name):
#                    setattr(tunnel_master_form, field_name, field_value)
#        else:
#            tunnel_master_form.public_ip_or_ddns_hostname.data = json.loads(subprocess.Popen(
#            'scripts/show_public_ip.sh', stdout=subprocess.PIPE
#            ).communicate()[0])["public_ipv4"]
#            tunnel_master_form.mdns.data = True

    if tunnel_master_form.validate_on_submit():
        print(json.dumps(tunnel_master_form.data, indent=2))

        #GET MAIN INFO
#        tunnel_data = {
#            "device_id": device_id,
#            "type": tunnel_master_form.data["deviceType"],
#            "public_ip_or_ddns_hostname": tunnel_master_form.data["public_ip_or_ddns_hostname"],
#            "port": tunnel_master_form.data["tunnel_port"],
#            "protocol": tunnel_master_form.data["protocol"],
#            "master_networks": [],
#            "clients": []
#        }

        # ADD MASTER NETWORKS TO THE DICTIONARY
#        for i in range(len(tunnel_master_form.data.getlist("master_networks.server_network"))):
#            network = {
#                "server_network": tunnel_master_form.data.getlist("master_networks.server_network")[i],
#                "server_subnet": tunnel_master_form.data.getlist("master_networks.server_subnet")[i]
#            }
#            tunnel_data["master_networks"].append(network)

        # ADD CLIENTS AND THEIR CLIENT NETWORKS TO THE DICTIONARY
#        for i in range(len(tunnel_master_form.data.getlist("clients.client_id"))):
#            client = {
#                "client_id": tunnel_master_form.data.getlist("clients.client_id")[i],
#                "client_networks": []
#            }
#            for j in range(len(tunnel_master_form.data.getlist(f"clients.clients-{i}.client_networks.client_network"))):
#                client_network = {
#                    "client_network": tunnel_master_form.data.getlist(f"clients.clients-{i}.client_networks.client_network")[j],
#                    "client_subnet": tunnel_master_form.data.getlist(f"clients.clients-{i}.client_networks.client_subnet")[j]
#                }
#                client["client_networks"].append(client_network)
#            tunnel_data["clients"].append(client)
#        print(tunnel_data)
        save_tunnel_configuration(tunnel_master_form.data)


#        subprocess.Popen([
#            "scripts/change_vpn.sh",
#            "-t", "server",
#            "-b", {
#                "normal": "off",
#                "bridge": "on",
#            }[tunnel_master_form.data["tunnel_type"]],
#            "-h", tunnel_master_form.data["public_ip_or_ddns_hostname"],
#            "-p", tunnel_master_form.data["protocol"],
#            "-n", str(tunnel_master_form.data["tunnel_port"]),
#            "-s", "",  # TODO
#            "-c", "",  # TODO
#            "-d", "",  # TODO
#        ])

        return {
            'form': form,
            'device_id': device_id,
            'tunnel_master_form': tunnel_master_form,
            'tunnel_non_master_form': tunnel_non_master_form,
            'download_btn_enabled': 'enabled',
            'download_msg_class': 'alert-success',
        }

    print(form.errors)
    return {
        'form': form,
        'device_id': device_id,
        'tunnel_master_form': tunnel_master_form,
        'tunnel_non_master_form': tunnel_non_master_form,
        'download_btn_enabled': 'disabled',
        'download_msg_class': 'alert-danger' if tunnel_master_form.errors else 'alert-primary',
    }


@app.route("/tunnel/download/<dl_uuid>", methods=["GET"])
@do_response_from_context
def tunnel_download(dl_uuid):
    return {}

@app.route("/tunnel/upload", methods=["GET", "POST"])
@do_response_from_context
def tunnel_upload():
    return {}


@app.route("/diagnostics", methods=["GET", "POST"])
@do_response_from_context
def diagnostics():
    ip_change_info = show_ip()
    public_ip_info = show_public_ip()
    def or_info(val):
        return val or 'no info could be retrieved'

    return {
        'ip_type': ip_change_info.ip_type,
        'ip_address': or_info(ip_change_info.ip_address),
        'subnet': or_info(ip_change_info.subnet),
        'gateway': or_info(ip_change_info.gateway),
        'dns_servers': ','.join(or_info(ip_change_info.dns_servers)),
#        'public_ip_address': requests.get('https://ipv4.icanhazip.com/').text
        'public_ip_address': or_info(public_ip_info.public_ipv4)
    }


@app.route("/log-file", methods=["GET", ])
def get_log_file():
    with open(os.getenv('LOG_PATH', '/'), 'r+') as f:
        return f.readlines()


if __name__ == "__main__":
    is_debug = os.getenv('DEBUG', 'False').lower() == 'true'
    port = os.getenv('PORT', 8080)
    try:
        with open(BASE_DIR / IP_CONFIG_FILE, 'r') as f:
            try_read = f.read()
    except Exception:
        with open(BASE_DIR / IP_CONFIG_FILE, 'w') as f:
            default_config = IpAddressChangeInfo('dhcp', None, None, None, None)
            f.write(default_config.to_json())

    if is_debug:
        app.run(debug=is_debug, host="0.0.0.0")
    else:
        from waitress import serve
        serve(app, host="0.0.0.0", port=int(port))
