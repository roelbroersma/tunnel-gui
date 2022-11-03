from flask_wtf import FlaskForm

from wtforms import StringField, PasswordField, RadioField, BooleanField
from wtforms.validators import (
    DataRequired,
    Length,
    ValidationError,
    InputRequired,
    IPAddress,
    ValidationError,
)


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


class PasswordForm(FlaskForm):
    extra_args = {"class": "form-control", "placeholder": "Password"}
    extra_args_again = {"class": "form-control", "placeholder": "Password again"}
    password = PasswordField(
        "Password", validators=[DataRequired(), Length(8, 128)], render_kw=extra_args
    )
    password_again = PasswordField(
        "Password (verify)",
        validators=[DataRequired(), Length(8, 128)],
        render_kw=extra_args_again,
    )

    def validate_password(self, password):
        if password != self.password_again:
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
