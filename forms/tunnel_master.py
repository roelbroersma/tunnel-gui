from flask_wtf import FlaskForm
from wtforms import (
    BooleanField,
    FieldList,
    Form,
    FormField,
    IntegerField,
    RadioField,
    SelectField,
    StringField,
)
from wtforms.validators import IPAddress, NumberRange

from widgets import MasterRowWidget
from forms.subnet_choices import SUBNET_CHOICES


class MasterNetworkForm(Form):
    server_ip = StringField(
        '',
        validators=[IPAddress(), ],
        render_kw={"placeholder": "192.168.0.0", "style": "width: 94%"},
    )
    server_subnet = SelectField(
        "",
        choices=SUBNET_CHOICES,
        default="255.255.255.0",
        render_kw={"style": "height: 30px;"}
    )


class ClientNetworkForm(Form):
    client_id = StringField(
        "Client device ID(s)",
        render_kw={"placeholder": "Client device ID"},
    )
    client_ip = StringField(
        '',
        validators=[IPAddress(), ],
        render_kw={"placeholder": "192.168.0.0", "style": "width: 94%"},
    )
    client_subnet = SelectField(
        "",
        choices=SUBNET_CHOICES,
        default="255.255.255.0",
        render_kw={"style": "height: 30px;"}
    )


class TunnelMasterForm(FlaskForm):
    tunnel_type = RadioField(
        "Type",
        choices=[
            ("normal", "Normal"),
            ("bridge", "Bridge")
        ],
        default="normal",
        render_kw={"class": "tunnel-type-popup", "style": "padding-left: 0"},
    )

    public_ip_or_ddns_hostname = StringField(
        "Public IP or (DDNS) Hostname",
        validators=[IPAddress(), ],
        render_kw={"placeholder": "192.168.0.10", "class": "col-12"},
    )
    tunnel_port = IntegerField(
        "Port",
        validators=[NumberRange(min=1, max=65535)],
        default=443,
        render_kw={"class": "col-12"}
    )
    protocol = SelectField(
        "Protocol",
        choices=[
            ("tcp", "TCP"),
            ("udp", "UDP")
        ],
        default="tcp",
        render_kw={"class": "mb-0", "style": "height: 30px"}
    )
    master_networks = FieldList(
        FormField(MasterNetworkForm),
        min_entries=1,
        max_entries=8,
        render_kw={"class": "wow-item"}
    )
    client_networks = FieldList(
        FormField(ClientNetworkForm),
        min_entries=1,
        max_entries=8,
        render_kw={"class": "wow-item"}
    )
    mdns = BooleanField("Enable MDNS (Avahi Daemon)")
    pimd = BooleanField("Enable PIMD (Multicast Routing)")
