from flask_wtf import FlaskForm
from wtforms import (
    BooleanField,
    FieldList,
    FormField,
    IntegerField,
    RadioField,
    SelectField,
    StringField,
)
from wtforms.validators import IPAddress

from forms.master_network import MasterNetworkForm
from widgets import MasterRowWidget


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
        validators=[],
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
        min_entries=2,
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
