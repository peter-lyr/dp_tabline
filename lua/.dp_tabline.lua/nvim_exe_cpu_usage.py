import sys
import time

import psutil

if len(sys.argv) < 3:
    sys.exit(1)
pid = int(sys.argv[1])
p = psutil.Process(pid)
file = sys.argv[2]

interval = 1
while True:
    cpu_percent = p.cpu_percent(interval=1)
    line = str(cpu_percent).encode('utf-8')
    with open(file, "wb") as f:
        f.write(line)
    time.sleep(interval)
