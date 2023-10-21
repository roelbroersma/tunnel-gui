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
from wtforms.validators import IPAddress, Length, NumberRange

from forms.subnet_choices import SUBNET_CHOICES


class MasterNetworkForm(Form):
    server_network = StringField(
        "",
        validators=[IPAddress()],
        render_kw={"placeholder": "192.168.0.0", "style": "width: 94%"},
    )
    server_subnet = SelectField(
        "",
        choices=SUBNET_CHOICES,
        default="255.255.255.0",
        render_kw={"style": "height: 30px;"},
    )


class ClientNetworkForm(Form):
    client_network = StringField(
        "",
        validators=[IPAddress()],
        render_kw={"placeholder": "192.168.0.0", "style": "width: 94%"},
    )
    client_subnet = SelectField(
        "",
        choices=SUBNET_CHOICES,
        default="255.255.255.0",
        render_kw={"style": "height: 30px;"},
    )


class ClientForm(Form):
    client_id = StringField(
        "Client device ID(s)",
        validators=[Length(10, 60)],
        render_kw={"placeholder": "Client device ID", "style": "width: 94%"},
    )
    client_networks = FieldList(
        FormField(ClientNetworkForm),
        min_entries=1,
        render_kw={"class": "wow-item"},
    )


class TunnelMasterForm(FlaskForm):
    tunnel_type = RadioField(
        "Type",
        choices=[("normal", "Normal"), ("bridge", "Bridge")],
        default="normal",
        render_kw={"class": "tunnel-type-popup", "style": "padding-left: 0"},
    )

    public_ip_or_ddns_hostname = StringField(
        "Public IP or (DDNS) Hostname",
        validators=[IPAddress()],
        render_kw={"placeholder": "192.168.0.10", "class": "col-12"},
    )
    tunnel_port = IntegerField(
        "Port",
        validators=[NumberRange(min=1, max=65535)],
        default=443,
        render_kw={"class": "col-12"},
    )
    protocol = SelectField(
        "Protocol",
        choices=[("tcp", "TCP"), ("udp", "UDP")],
        default="tcp",
        render_kw={"class": "mb-0", "style": "height: 30px"},
    )
    master_networks = FieldList(
        FormField(MasterNetworkForm),
        min_entries=1,
        render_kw={"class": "wow-item"},
    )
    clients = FieldList(
        FormField(ClientForm),
        min_entries=1,
    )
    mdns = BooleanField("Enable MDNS (Avahi Daemon)")
    pimd = BooleanField("Enable PIMD (Multicast Routing)")
    stp = BooleanField("Enable STP (Spanning Tree Protocol)")
    newkeys = BooleanField("Generate new keys")
