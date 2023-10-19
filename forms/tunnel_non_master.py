from flask_wtf import FlaskForm
from flask_wtf.file import FileField, FileRequired, FileAllowed
from wtforms import (
        SubmitField,
)

from wtforms.validators import DataRequired

class TunnelNonMasterForm(FlaskForm):
#    file_upload = FileField('Upload Client Keys', validators=[DataRequired()])
    file_upload = FileField('Upload Client Keys', validators=[FileRequired(),FileAllowed(['zip','.conf'],'Only Client Key files (.conf or .zip) are allowed!')])
    submit = SubmitField('Upload and Save')

