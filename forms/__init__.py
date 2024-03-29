import re

from flask_wtf import FlaskForm

from wtforms import BooleanField, FieldList, PasswordField, RadioField, StringField, SubmitField

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
    ip_type = RadioField(
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
    dns_servers = StringField(
        "DNS Server",
        validators=[IPAddress(), ],
        render_kw={"class": IP_INPUT_DEFAULT_CLASSES, "placeholder": "8.8.8.8"},
    )
    subnet = StringField(
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
        ip_type = self.data['ip_type']
        if ip_type == 'static':
            super_result = super().validate(extra_validators)
            return super_result
        else:
            return True
        return False

    def get_generated_data(self):
        ip_type = self.ip_type.data
        ip = self.ip_address.data
        gateway = self.gateway.data
        network = self.subnet.data
        dns = self.dns_servers.data
        return IpAddressChangeInfo(
            ip_type=ip_type,
            ip_address=ip,
            subnet=network,
            dns_servers=dns,
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


class UpdateForm(FlaskForm):
    check_online = SubmitField("Check for Software Updates")
    update_dietpi_auto_enable = SubmitField("Enable DietPi automatic updates")
    update_dietpi_auto_disable = SubmitField("Disable DietPi automatic updates")
    update_core_auto_enable = SubmitField("Enable OS automatic updates")
    update_core_auto_disable = SubmitField("Disable OS automatic updates")
    update_app = SubmitField("Update T1 Sofware")
    update_app_force = BooleanField("Force/Overwrite update?")
    update_core = SubmitField("Update Operating System")
    update_dietpi = SubmitField("Update DietPi Software")

class RebootForm(FlaskForm):
    reboot = SubmitField("Reboot system")

