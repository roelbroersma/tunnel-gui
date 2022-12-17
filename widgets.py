from markupsafe import Markup


class MasterRowWidget:
    def __call__(self, field, **kwargs):
        html = ''.join(
            f'<div class="col-6">{str(subfield)}</div>' for subfield in field
        )
        return Markup(html)
