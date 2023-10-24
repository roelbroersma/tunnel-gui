import os
import json
from pathlib import Path
import requests
import shelve
import subprocess
import uuid

from dotenv import load_dotenv
from flask import Flask, redirect, url_for, request, Response, session
from flask import render_template as flask_render_template
from flask import send_file
from pydantic import BaseModel

from forms import IpAddressChangeForm, PasswordForm, SignInForm, UpdateForm, RebootForm, TunnelMasterForm, TunnelNonMasterForm
from utils import do_change_password, change_ip, get_token, get_passwords, IpAddressChangeInfo, show_ip, PublicIpInfo, show_public_ip, generate_keys, generate_server_config, generate_client_config, save_tunnel_configuration, load_device_type, load_tunnel_configuration, handle_uploaded_file, core_upgrade, get_version, app_upgrade, do_reboot


from flask_wtf.csrf import CSRFProtect

BASE_DIR = Path(__file__).resolve().parent
DEFAULT_EXECUTABLE = '/bin/bash'
load_dotenv(BASE_DIR / ".env")

UPDATE_LOG = BASE_DIR / "logs/update.log"

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY")
app.config['SECRET_KEY'] = os.getenv("SECRET_KEY")

csrf = CSRFProtect(app)

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
            linked_route_method_name='update',
            title='Update',
            svg_icon_id='update'
        ),
        MenuItemInfo(
            linked_route_method_name='reboot',
            title='Reboot',
            svg_icon_id='reboot'
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

#    if route_name == "rebooting":
#        template_name = f"{route_name}.html"

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

        if isinstance(context, Response):
            return context  # Return the response object directly

        if context is not None and 'callback' in context:
            return context['callback']()

        return render_template(route_name, **context)
    wrapper.__name__ = make_context_func.__name__
    return wrapper


@app.route("/signin", methods=["GET", "POST"])
def signin():
    form = SignInForm(request.form, meta={"csrf": True})

    if form.validate_on_submit():
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
    form = IpAddressChangeForm(request.form, meta={"csrf": True})

    if form.validate_on_submit():
        form_generated_data = form.get_generated_data()
        change_ip(form_generated_data)
    
    else:
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
    form = PasswordForm(request.form, meta={"csrf": True})

    if form.validate_on_submit():
        # shelve sync
        do_change_password(form.pass1.data)
        return {'callback': lambda: redirect(url_for('signin'), code=302)}
    return {'form': form}


@app.route("/tunnel", methods=["GET", "POST"])
@do_response_from_context
def tunnel():
#    form = TunnelForm()
    tunnel_master_form = TunnelMasterForm(request.form, meta={"csrf": True})
    tunnel_non_master_form = TunnelNonMasterForm(meta={"csrf": True}) #REMOVE THE request.form here, so it will automtically see we have also request.files

    deviceType = request.form.get('deviceType', default=None)
    if deviceType is None:
        deviceType = load_device_type()

    device_id = json.loads(subprocess.Popen(BASE_DIR / 'scripts/show_machine_id.sh', stdout=subprocess.PIPE).communicate()[0])["machine_id"]


    if (not tunnel_master_form.is_submitted() and not tunnel_non_master_form.is_submitted()):
        tunnel_master_form = load_tunnel_configuration(tunnel_master_form)


    if tunnel_master_form.validate_on_submit():

        #GET CLIENT IDS FROM OUR FORM
        client_ids = [client['client_id'] for client in tunnel_master_form.data['clients']]

        #CALL THE GENERATE_KEYS FUNCTION (IF GENERATE KEYS IS CHECKED OR IF NEW CLIENTS ARE SET OR IF NO-MASTER KEYS ARE SET)
        generate_keys( device_id, client_ids, bool(tunnel_master_form.data["newkeys"]) )

        #SET BRIDGE TO ON OR OFF
        bridge = "on" if tunnel_master_form.data['tunnel_type'] == "bridge" else "off"

        # CREATE DAEMONS ARRAY
        features = []
        if tunnel_master_form.data['mdns']:
            features.append('mdns')
        if tunnel_master_form.data['pimd']:
            features.append('pimd')
        if tunnel_master_form.data['stp']:
            features.append('stp')

        #GENERATE THE CONFIG FOR THE SERVER, THIS WILL ALSO CREATE A CLIENT_CONFIG.ZIP FILE TO DOWNLOAD FOR THE CLIENTS
        generate_server_config ( bridge, tunnel_master_form.data["public_ip_or_ddns_hostname"], tunnel_master_form.data["protocol"], tunnel_master_form.data["tunnel_port"], tunnel_master_form.data["master_networks"], tunnel_master_form.data["clients"], features )

        # ALWAYS SET NEWKEYS TO FALSE
        tunnel_master_form.newkeys.data = None

        #SAVE A JSON FILE
        save_tunnel_configuration(tunnel_master_form.data)

        return {
#            'form': form,
            'device_type': 'master',
            'device_id': device_id,
            'tunnel_master_form': tunnel_master_form,
            'tunnel_non_master_form': tunnel_non_master_form,
            'download_btn_enabled': 'enabled',
            'download_msg_class': 'alert-success',
        }


    if tunnel_non_master_form.validate_on_submit():
        #SAVE UPLOADED FILE
        success1 = handle_uploaded_file(request.files['file_upload'])

        message_class = 'alert-danger'

        if success1:
            #GENERATE THE CLIENT CONFIG, BASED ON THE UPLOADED FILE
            success2 = generate_client_config()
            if success2:
                message_class = 'alert-success'
            else:
               print(success2)
               tunnel_non_master_form.submit.errors.append("File for this Client/Device ID not found or problems with starting!")
        else:
            tunnel_non_master_form.submit.errors.append("File could not be uploaded!")

        return {
                'device_type': 'notMaster',
                'device_id': device_id,
                'tunnel_master_form': tunnel_master_form,
                'tunnel_non_master_form': tunnel_non_master_form,
                'download_btn_enabled': 'disabled',
                'download_msg_class': message_class,
            }

    #ALWAYS RETURN THE FORMS WHEN NOT SUBMITTED OR NOT VALIDATED
    return {
        'device_type': deviceType,
        'device_id': device_id,
        'tunnel_master_form': tunnel_master_form,
        'tunnel_non_master_form': tunnel_non_master_form,
        'download_btn_enabled': 'disabled',
        'download_msg_class': 'alert-danger' if tunnel_master_form.errors else 'alert-primary',
    }


@app.route("/tunnel/download-client-config", methods=["GET"])
#@do_response_from_context
def tunnel_download_client_config():
    return send_file(str(BASE_DIR / 'configs' / 'client_config.zip'), as_attachment=True)

@app.route("/tunnel/upload", methods=["GET", "POST"])
@do_response_from_context
def tunnel_upload():
    return {}

@app.route("/update", methods=["GET", "POST"])
@do_response_from_context
def update():

    form = UpdateForm(request.form, meta={"csrf": True})

    message=''
    try:
        if form.validate_on_submit():
            if 'check_online' in request.form:
                version = get_version("all")
            elif 'update_auto_enable' in request.form:
                core_upgrade("auto")
                version = get_version("local")
            elif 'update_auto_disable' in request.form:
                core_upgrade("manual")
                version = get_version("local")
            elif 'update_app' in request.form:
                app_upgrade("now")
                message="Software will be updated in background, do not close this screen!"
                version = get_version("local")
            elif 'update_core' in request.form:
                core_upgrade('now')
                message="Software will be updated in the background, do not close this screen!"
                version = get_version("local")
            else:
                version = get_version("local")
        else:
            version = get_version("local")
    except:
        version = {}

    return {
        'version': version,
        'message': message,
        'form': form,
    }



@app.route("/reboot", methods=["GET", "POST"])
@do_response_from_context
def reboot():
    form = RebootForm(request.form, meta={"csrf": True})

    if form.validate_on_submit():
        do_reboot()
        return redirect(url_for('rebooting'))

    return {
        'form': form,
    }


@app.route("/rebooting")
def rebooting():
    return render_template('rebooting')


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


@app.route("/openvpn-status", methods=["GET", ])
def get_openvpn_status():
    try:
        with open(os.getenv('OPENVPN_STATUS_PATH', '/'), 'r+') as f:
            return f.readlines()
    except:
        pass

    return ""

@app.route("/update-log", methods=["GET", ])
def get_update_log():
    try:
        with open(UPDATE_LOG, 'r+') as f:
            return f.readlines()
    except:
        pass

    return ""

if __name__ == "__main__":
    is_debug = os.getenv('DEBUG', 'False').lower() == 'true'
    port = os.getenv('PORT', 8080)
    IP_CONFIG_FILE = BASE_DIR / "ipconfig.json"
#    try:
#        with open(BASE_DIR / IP_CONFIG_FILE, 'r') as f:
#            try_read = f.read()
#    except Exception:
#        with open(BASE_DIR / IP_CONFIG_FILE, 'w') as f:
#            default_config = IpAddressChangeInfo('dhcp', None, None, None, None)
#            f.write(default_config.to_json())

    if is_debug:
        app.run(debug=is_debug, host="0.0.0.0", port=int(port))
    else:
        from waitress import serve
        serve(app, host="0.0.0.0", port=int(port))
