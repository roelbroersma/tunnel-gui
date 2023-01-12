from flask_wtf import FlaskForm
from wtforms import FileField

class TunnelNonMasterForm(FlaskForm):
    upload_zip = FileField()
