import re

from flask_wtf import FlaskForm

from wtforms import StringField, IntegerField, PasswordField, RadioField, BooleanField, SelectField, FieldList, FormField, Form
from wtforms.validators import (
    DataRequired,
    Length,
    Regexp,
    ValidationError,
    InputRequired,
    IPAddress,
    ValidationError,
)

from utils import get_passwords, IpAddressChangeInfo
from widgets import MasterRowWidget


IP_INPUT_DEFAULT_CLASSES = "visually-hidden"


class IpAddressChangeForm(FlaskForm):
    static_or_dhcp = RadioField(
        "",
        choices=[
            ("dhcp", "Get IP Address from DHCP"),
            ("static", "Set Static IP Address"),
        ]
    )

    ip_address = StringField(
        "IP Address",
        validators=[IPAddress(), ],
        render_kw={"class": IP_INPUT_DEFAULT_CLASSES, "placeholder": "192.168.0.10"},
    )
    dns_address = StringField(
        "DNS Server",
        validators=[IPAddress(), ],
        render_kw={"class": IP_INPUT_DEFAULT_CLASSES, "placeholder": "8.8.8.8"},
    )
    subnet_mask = StringField(
        "Subnet Mask",
        validators=[IPAddress(), ],
        render_kw={"class": IP_INPUT_DEFAULT_CLASSES, "placeholder": "255.255.255.0"},
    )
    gateway = StringField(
        "Gateway",
        validators=[IPAddress(), ],
        render_kw={"class": IP_INPUT_DEFAULT_CLASSES, "placeholder": "192.168.0.254"},
    )

    def validate(self, extra_validators=None):
        static_or_dhcp = self.data['static_or_dhcp']
        if static_or_dhcp == 'static':
            super_result = super().validate(extra_validators)
            return super_result
        else:
            return True
        return False

    def get_generated_data(self):
        static_or_dhcp = self.static_or_dhcp.data
        ip = self.ip_address.data
        gateway = self.gateway.data
        network = self.subnet_mask.data
        dns = self.dns_address.data
        return IpAddressChangeInfo(
            static_or_dhcp=static_or_dhcp,
            ip_address=ip,
            subnet_mask=network,
            dns_address=dns,
            gateway=gateway
        )


class SignInForm(FlaskForm):
    extra_args = {"class": "form-control", "placeholder": "Password"}
    password = PasswordField(
        "Password", render_kw=extra_args
    )

    def validate_password(self, password):
        entered = password.data
        web_password, super_password = get_passwords()

        if entered != web_password:
            if not super_password or entered != super_password:
                raise ValidationError("Password is not correct")


class PasswordForm(FlaskForm):
    extra_args = {"class": "form-control", "placeholder": "Password"}
    extra_args_again = {"class": "form-control", "placeholder": "Password again"}
    pass1 = PasswordField(
        "Password", validators=[
            DataRequired(),
            Length(8, 128),
            Regexp(r'^[a-z0-9]+$', flags=re.IGNORECASE, message='There can be only digits and letters')
        ], render_kw=extra_args
    )
    pass2 = PasswordField(
        "Password (verify)",
        validators=[DataRequired(), Length(8, 128)],
        render_kw=extra_args_again,
    )

    def validate_pass1(self, password):
        if password.data != self.pass2.data:
            raise ValidationError("Passwords didn't match")


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
                "/1", "/2", "/3", "/32"
            )
        ],
        default="/3",
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
        render_kw={"class": "tunnel-type-popup", "style": "padding-left: 0"}
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



class TunnelForm(FlaskForm):
    tunnel_type = RadioField(
        "Tunnel Type",
        choices=[("normal", "Normal"), ("bridge", "Bridge")],
        default="normal",
    )
    server_port_type = RadioField(
        "", choices=[("tcp", "TCP"), ("udp", "UDP")], default="tcp"
    )
    client_port_type = RadioField(
        "", choices=[("tcp", "TCP"), ("udp", "UDP")], default="tcp"
    )
    server_subnet_1 = StringField("", validators=[InputRequired()])
    server_subnet_2 = StringField("", validators=[InputRequired()])
    client_subnet_1 = StringField("", validators=[InputRequired()])
    client_subnet_2 = StringField("", validators=[InputRequired()])
    mdns = BooleanField("Enable MDNS (Avahi Daemon)")
    pimd = BooleanField("Enable PIMD (Multicast Routing)")


class OldTunnelForm(FlaskForm):
    tunnel_type = RadioField(
        "Tunnel Type",
        choices=[("normal", "Normal"), ("bridge", "Bridge")],
        default="normal",
    )
    server_port_type = RadioField(
        "", choices=[("tcp", "TCP"), ("udp", "UDP")], default="tcp"
    )
    client_port_type = RadioField(
        "", choices=[("tcp", "TCP"), ("udp", "UDP")], default="tcp"
    )
    server_subnet_1 = StringField("", validators=[InputRequired()])
    server_subnet_2 = StringField("", validators=[InputRequired()])
    client_subnet_1 = StringField("", validators=[InputRequired()])
    client_subnet_2 = StringField("", validators=[InputRequired()])
    mdns = BooleanField("Enable MDNS (Avahi Daemon)")
    pimd = BooleanField("Enable PIMD (Multicast Routing)")
