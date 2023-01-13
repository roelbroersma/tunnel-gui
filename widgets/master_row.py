from markupsafe import Markup


class MasterRowWidget:
    def __call__(self, field, **kwargs):
        col_width = [6, 4]
        html = ''.join(
            f'<div class="col-{col_width[i]}">{str(subfield)}</div>' for i, subfield in enumerate(field)
        )
        return Markup(html)
