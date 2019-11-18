# https://github.com/cloudigrade/cloudigrade/pull/342#discussion_r195561245

things = [None, '🎉', 1, 1., 1j, b'123', True, (1, 2), [1, 2], {1, 2, 3}, {'hey': 'arnold!'}, datetime.datetime.now()]

for thing in things:
    print(jsonpickle.decode(jsonpickle.encode(thing)))

for thing in things:
    try:
        print(json.loads(json.dumps(thing)))
    except TypeError:
        print(f'** json could not dumps {thing}')
