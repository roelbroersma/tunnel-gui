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


class MasterNetworkForm(Form):
    server_ip = StringField(
        '',
        validators=[IPAddress(), ],
        render_kw={"placeholder": "192.168.0.0", "style": "width: 94%"},
    )
    server_subnet = SelectField(
        "",
        choices=[
            (x, x) for x in (
                "255.255.255.255", "255.255.255.254", "255.255.255.252", "255.255.255.248", "255.255.255.240", "255.255.255.224", "255.255.255.192", "255.255.255.128", "255.255.255.0", "255.255.254.0", "255.255.252.0", "255.255.248.0", "255.255.240.0", "255.255.224.0", "255.255.192.0", "255.255.128.0", "255.255.0.0", "255.254.0.0", "255.252.0.0", "255.248.0.0", "255.240.0.0", "255.224.0.0", "255.192.0.0", "255.128.0.0", "255.0.0.0", "254.0.0.0", "252.0.0.0", "248.0.0.0", "240.0.0.0", "224.0.0.0", "192.0.0.0", "128.0.0.0", "0.0.0.0"
            )
        ],
        default="255.255.255.0",
        render_kw={"style": "height: 30px;" }
    )


class ClientNetworkForm(Form):
    client_ip = StringField(
        '',
        validators=[IPAddress(), ],
        render_kw={"placeholder": "192.168.0.0", "style": "width: 94%"},
    )
    server_subnet = SelectField(
        "",
        choices=[
            (x, x) for x in (
                "255.255.255.255", "255.255.255.254", "255.255.255.252", "255.255.255.248", "255.255.255.240", "255.255.255.224", "255.255.255.192", "255.255.255.128", "255.255.255.0", "255.255.254.0", "255.255.252.0", "255.255.248.0", "255.255.240.0", "255.255.224.0", "255.255.192.0", "255.255.128.0", "255.255.0.0", "255.254.0.0", "255.252.0.0", "255.248.0.0", "255.240.0.0", "255.224.0.0", "255.192.0.0", "255.128.0.0", "255.0.0.0", "254.0.0.0", "252.0.0.0", "248.0.0.0", "240.0.0.0", "224.0.0.0", "192.0.0.0", "128.0.0.0", "0.0.0.0"
            )
        ],
        default="255.255.255.0",
        render_kw={"style": "height: 30px;" }
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
        FormField(
            MasterNetworkForm,
            widget=MasterRowWidget()
        ),
        min_entries=1,
        max_entries=8,
        render_kw={"class": "wow-item"}
    )
    client_networks = FieldList(
        FormField(
            ClientNetworkForm,
            widget=MasterRowWidget()
        ),
        min_entries=1,
        max_entries=8,
        render_kw={"class": "wow-item"}
    )
    client_ids = StringField(
        "Client device ID(s)",
        render_kw={"class": "add-more-items visually-hidden"}
    )

    # server_subnet_1 = StringField("", validators=[InputRequired()])
    # server_subnet_2 = StringField("", validators=[InputRequired()])
    # client_subnet_1 = StringField("", validators=[InputRequired()])
    # client_subnet_2 = StringField("", validators=[InputRequired()])

    mdns = BooleanField("Enable MDNS (Avahi Daemon)")
    pimd = BooleanField("Enable PIMD (Multicast Routing)")
