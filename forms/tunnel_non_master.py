from flask_wtf import FlaskForm
from wtforms import (
        FileField,
)

from wtforms.validators import DataRequired

class TunnelNonMasterForm(FlaskForm):
    file_upload = FileField('Upload Client Keys', validators=[DataRequired()])

