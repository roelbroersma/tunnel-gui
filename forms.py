import re
import os
from pathlib import Path

from flask_wtf import FlaskForm

from wtforms import StringField, PasswordField, RadioField, BooleanField
from wtforms.validators import (
    DataRequired,
    Length,
    Regexp,
    ValidationError,
    InputRequired,
    IPAddress,
    ValidationError,
)

from utils import get_passwords


class StaticIpForm(FlaskForm):
    ip_address = StringField(
        "IP Address",
        validators=[InputRequired(), IPAddress()],
        render_kw={"placeholder": "123.45.678.9"},
    )
    subnet_mask = StringField(
        "Subnet Mask",
        validators=[InputRequired()],
        render_kw={"placeholder": "255.0.0.0"},
    )
    gateway = StringField(
        "Gateway",
        validators=[InputRequired()],
        render_kw={"placeholder": "192.168.2.28"},
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
