from jinja2 import Template

NAME = 'template.txt'
DICT = {
    'iternum' : 32,
    'depth' : 4,
}

def generate(filename, temp_dict):
    text = open(filename, 'r').read()
    template = Template(text)
    rslt = template.render(temp_dict)
    return rslt

print(generate(NAME, DICT))

