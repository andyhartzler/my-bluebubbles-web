# BlueBubbles Clients

BlueBubbles is an open-source and cross-platform ecosystem of apps aimed to bring iMessage to Android, Windows, Linux, and the Web! With BlueBubbles, you'll be able to send messages, media, and much more to your friends and family.

**Please note that BlueBubbles requires a Mac and an Apple ID to function! A macOS VM on Windows or Linux can suffice as well.

Key Features:

- Send & receive texts, media, and location
- View tapbacks, reactions, stickers, and read/delivered timestamps
- Create new chats
- View replies (requires MacOS 11+)
- Mute or archive conversations
- Robust theming engine
- Choose between an iOS or Android-style interface
- Lots of customizations and options to personalize your experience
- Full cross-platform support - message across Android, Linux, Windows, the Web, and even macOS!

Private API Features:

- See and send typing indicators
- Send tapbacks, read receipts, subject messages, messages with effects, and replies (replies require MacOS 11+)
- Mark chats read on the server Mac
- Rename group chats
- Add and remove participants from group chats

**Private API Features are not enabled by default and require extra configurations. Learn how to set up Private API Features [here](https://docs.bluebubbles.app/helper-bundle/installation)**

Screenshots:

<table>
  <tr>
    <td align="center">Chat List</td>
     <td align="center">Message View</td>
     <td align="center">Private API Features</td>
  </tr>
  <tr>
    <td><img src="https://raw.githubusercontent.com/BlueBubblesApp/bluebubbles-app/master/screenshots/Samsung%20Galaxy%20S10%2B%20Prism%20Black%20-%20imessage_framed.png" width=270></td>
    <td><img src="https://raw.githubusercontent.com/BlueBubblesApp/bluebubbles-app/master/screenshots/Samsung%20Galaxy%20S10+%20Prism%20Black%20-%20messaging_framed.png" width=270></td>
    <td><img src="https://raw.githubusercontent.com/BlueBubblesApp/bluebubbles-app/master/screenshots/Samsung%20Galaxy%20S10+%20Prism%20Black%20-%20privateAPI_framed.png" width=270></td>
  </tr>
 </table>

If you need help setting up the app, have any issues or feature requests, or just want to come hang out, feel free to join our Discord, linked below! We hope you enjoy using the app!

## Useful links

* Our Website: [here](https://bluebubbles.app)
* Discord: [here](https://discord.gg/4F7nbf3)!
    - We highly encourage users to join to get in direct communication with the developers and community
* GitHub: [here](https://github.com/BlueBubblesApp)
    - Please submit any issues with the app here so we can properly track them! Remember to search before opening a ticket :)
    - Contribution is *always* appreciated and needed! Feel free to download our source, make changes, and submit a pull request.

## Getting Started

All Client builds can be found in [here](https://github.com/BlueBubblesApp/blueBubbles-app/releases).

All Server builds can be found in [here](https://github.com/BlueBubblesApp/BlueBubbles-Server/releases).

After downloading both, follow our tutorial [here](https://bluebubbles.app/install/).

## Contributing

Please check out our contribution guide here: [Contribution Guide](https://docs.bluebubbles.app/client/build-yourself-contribution-guide)

## Running the web client in GitHub Codespaces

The repository now includes a helper script that installs dependencies, builds the web bundle, and launches the development server inside a Codespace. It assumes you already have the Flutter SDK installed in the container (the default BlueBubbles devcontainer includes it).

1. Set the BlueBubbles server connection details as environment variables. These mirror the keys consumed by the Flutter app:

   ```bash
   export NEXT_PUBLIC_BLUEBUBBLES_HOST="https://messages.moydchat.org"
   export NEXT_PUBLIC_BLUEBUBBLES_PASSWORD="<your-guid-auth-key>"
   ```

   The app ships with the host above as a default for web builds, but exporting explicit values keeps local testing predictable.

2. Launch the helper script. It runs `flutter pub get`, `flutter build web`, and finally `flutter run` bound to a Codespaces-friendly interface and port:

   ```bash
   scripts/run_web.sh
   ```

   The script exposes the development server on port `3000` and binds to `0.0.0.0` by default so GitHub Codespaces can auto-forward it. Override the defaults by exporting `FLUTTER_WEB_PORT` or `FLUTTER_WEB_HOST` beforehand.

3. Once `flutter run` starts, Codespaces should offer to forward the selected port. Accept the prompt to open the live web client in your browser and connect it to your BlueBubbles server.

If you prefer to run the commands manually, replicate the steps shown in `scripts/run_web.sh`.
