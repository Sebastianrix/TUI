import time
from rich.live import Live
from rich.panel import Panel

t = 0
with Live(refresh_per_second=10) as live:
    while True:
        live.update(Panel(f"Ticks: {t}\nCtrl+C to quit"))
        t += 1
        time.sleep(0.1)
