def row_action_kind(command: list[str]) -> str:
    if command and command[0] == "wifi-scan":
        return "wifi-scan"
    if command and command[0] == "wifi-connect":
        return "wifi"
    if command and command[0] == "bluetooth-scan":
        return "bluetooth-scan"
    if command and command[0] == "bluetooth-connect":
        return "bluetooth"
    if command and command[0] == "audio-output":
        return "audio-output"
    if command and command[0] == "audio-input":
        return "audio-input"
    return "instant"
