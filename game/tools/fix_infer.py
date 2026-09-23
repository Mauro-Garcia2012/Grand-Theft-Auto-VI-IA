import re, subprocess, sys
for it in range(30):
    out = subprocess.run(["bash", "tools/import.sh"], capture_output=True, text=True).stdout
    errs = re.findall(r'Cannot infer the type of "(\w+)" variable.*?\n\s+at: GDScript::reload \(res://([^:]+):(\d+)\)', out)
    if not errs:
        print(out)
        break
    changed = 0
    for name, path, line in errs:
        lines = open(path).read().split("\n")
        i = int(line) - 1
        new = re.sub(r'\bvar %s\s*:=' % name, 'var %s =' % name, lines[i])
        if new == lines[i]:
            new = re.sub(r'\bfor %s\b' % name, 'for %s' % name, lines[i])
        if new != lines[i]:
            lines[i] = new
            changed += 1
            open(path, "w").write("\n".join(lines))
    print("iteration", it, "fixed", changed)
    if changed == 0:
        print(out)
        break
