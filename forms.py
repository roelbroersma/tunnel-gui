import re
import os
import json
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


class IpAddressChangeInfo:
    def __init__(self, static_or_dhcp, ip_address, dns_address, subnet_mask, gateway):
        self.static_or_dhcp = static_or_dhcp
        is_static = self.static_or_dhcp == 'static'
        def or_empty(val):
            return val if is_static else ''
        self.ip_address = or_empty(ip_address)
        self.dns_address = or_empty(dns_address)
        self.subnet_mask = or_empty(subnet_mask)
        self.gateway = or_empty(gateway)

    def to_json(self):
        data = {
            'staticOrDhcp': self.static_or_dhcp,
            'ipAddress': self.ip_address,
            'subnetMask': self.subnet_mask,
            'dnsAddress': self.dns_address,
            'gateway': self.gateway
        }
        return json.dumps(data, indent=4)

    @classmethod
    def from_json(cls, json_string):
        data = json.loads(json_string)
        return cls(
            static_or_dhcp=data['staticOrDhcp'],
            ip_address=data['ipAddress'],
            subnet_mask=data['subnetMask'],
            dns_address=data['dnsAddress'],
            gateway=data['gateway']
        )


class IpAddressChangeForm(FlaskForm):
    static = BooleanField("Static IP Address")
    dhcp = BooleanField("Get IP Address from DHCP")

    ip_address = StringField(
        "IP Address",
        validators=[IPAddress(), ],
        render_kw={"class": "form-control", "placeholder": "123.45.678.9"},
    )
    dns_address = StringField(
        "DNS Address",
        validators=[IPAddress(), ],
        render_kw={"class": "form-control", "placeholder": "8.8.8.8"},
    )
    subnet_mask = StringField(
        "Subnet Mask",
        validators=[IPAddress(), ],
        render_kw={"class": "form-control", "placeholder": "255.0.0.0"},
    )
    gateway = StringField(
        "Gateway",
        validators=[IPAddress(), ],
        render_kw={"class": "form-control", "placeholder": "192.168.2.28"},
    )

    def validate(self, extra_validators=None):
        dhcp = self.data['dhcp']
        static = self.data['static']
        msg = 'Should be selected only 1 option: DHCP or Static IP'
        self.dhcp.validate(self)
        self.static.validate(self)
        if dhcp and static:
            self.dhcp.errors.append(msg)
            self.static.errors.append(msg)
        elif not dhcp and not static:
            self.dhcp.errors.append(msg)
            self.static.errors.append(msg)
        elif static:
            super_result = super().validate(extra_validators)
            return super_result
        else:
            return True
        return False

    def get_generated_data(self):
        is_static = self.static.data
        static_or_dhcp = 'static' if is_static else 'dhcp'

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
