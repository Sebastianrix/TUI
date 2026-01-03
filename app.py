from textual.app import App, ComposeResult
from textual.widgets import Header, Footer, Static

class HelloApp(App):
    CSS = """
    Screen { align: center middle; }
    #box { padding: 2; border: round $accent; }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static("Hello TUI 👋\nPress Q to quit.", id="box")
        yield Footer()

    def on_key(self, event) -> None:
        if event.key.lower() == "q":
            self.exit()

if __name__ == "__main__":
    HelloApp().run()
