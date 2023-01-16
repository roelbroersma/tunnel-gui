import re

from flask_wtf import FlaskForm
from wtforms import BooleanField, FieldList, PasswordField, RadioField, StringField
from wtforms.validators import (
    DataRequired,
    InputRequired,
    IPAddress,
    Length,
    Regexp,
    ValidationError,
)

from forms.tunnel_master import TunnelMasterForm
from forms.tunnel_non_master import TunnelNonMasterForm
from utils import IpAddressChangeInfo, get_passwords

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
