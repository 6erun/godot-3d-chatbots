# Godot Multiplayer Template

This is a template for a 3D multiplayer game developed in Godot Engine 4.3. It provides a basic structure for a multiplayer setup, where each player has a nickname displayed above their character and the option to choose from four different skins: red, green, blue, or yellow.
<br>
This template is also available in the [Godot Asset Library](https://godotengine.org/asset-library/asset/3377).

## Game Server

### Create image with dedicated server

```bash
docker build --platform linux/x86_64 -t godot-server-demo:latest -f docker/Dockerfile .
```

### Push docker images to Docker Hub

Tag your image
```bash
docker tag godot-server-demo:latest my-namespace/godot-server-demo:latest
docker push my-namespace/godot-server-demo:latest
```

### Use Rift CLI to run the container

You need to login once to GitHub repository

```bash
rift docker login --username <your_username> --password <your_password>
```

You launch your container with similar syntax to docker command. You can bypass host port to use the same port as container (8080:8080 equals 8080)

```bash
rift docker run -d -p 8080/udp my-namespace/godot-server-demo:latest
```

You can list running containers with `rift docker ps` command. It will also display ip address that can be used to connect to the server.

## How to run the project

1. Download or clone this GitHub repository.
2. Open the project in [Godot Engine](https://godotengine.org).
3. Press <kbd>F5</kbd> or `Run Project`.

<br>

Note: To test multiplayer locally, follow these steps:
Go to `Debug` > `Customize Run Instances`, then enable `Enable Multiple Instances` and set the number of instances to run simultaneously. In this template, the host is not treated as a player.

## Controls

* <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> to move.
* <kbd>Shift</kbd> to run.
* <kbd>Space</kbd> to jump.
* <kbd>Esc</kbd> to quit.

## Credits

* 3D-Godot-Robot-Platformer-Character - https://github.com/AGChow/3D-Godot-Robot-Platformer-Character (CC0)
* Godot Multiplayer Template - https://github.com/devmoreir4/godot-3d-multiplayer-template