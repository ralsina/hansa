import re, pprint, json

data = {}
stack =[data]
dict_begin = re.compile(r"var (\w*) = .*{")
nested_dict_begin = re.compile(r'.*"(.*)": .*{')
dict_item = re.compile(r'.*"(.*)":\s+([+-]?([0-9]*[.])?[0-9]+),')

current = data
for line in open("go-enry/data/frequencies.go"):
    if "map[string]float64{}," in line:
        # special case, only empty map
        continue
    if dict_begin.match(line):
        dict_name = dict_begin.match(line).groups()[0]
        # print(dict_name)
        current[dict_name] = {}
        current = current[dict_name]
        stack.append(current)
    if nested_dict_begin.match(line):
        dict_name = nested_dict_begin.match(line).groups()[0]
        # print(dict_name, nested_dict_begin.match(line).groups())
        current[dict_name] = {}
        current = current[dict_name]
        stack.append(current)
    else:
        if '}\n' in line or "},\n" in line:
            # print("pop", line)
            stack.pop()
            if len(stack) == 0:
                break
            current = stack[-1]
            continue
        if dict_item.match(line):
            key, value = dict_item.match(line).groups()[0:2]
            # print(key,value)
            current[key] = float(value)

open ("frequencies.json", "w").write(json.dumps(data, indent=4))