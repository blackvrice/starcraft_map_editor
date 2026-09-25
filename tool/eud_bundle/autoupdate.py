"""Editor-managed euddraft distribution: updates are installed with the app.

This source replaces the upstream autoupdate module in the packaged library.
It deliberately imports no network, threading, process or filesystem APIs.
The external euddraft installation selected by a user is never modified.
"""


def issueAutoUpdate():
    print("[Map Editor] Bundled tool updates are managed by the application.")
