# Network setup

Fadera and the mixer must be on the **same local network** (same subnet). Internet access is not required.

## Typical setups

| Setup | Works | Notes |
|---|---|---|
| PC and mixer connected by cable to the same router or switch | Yes | Most reliable. |
| PC on the Wi-Fi of the router the mixer is connected to | Yes | Make sure it is not the router's *guest* network. |
| Mixer connected directly to the PC with one Ethernet cable | Yes | Give both a fixed IP in the same subnet (for example mixer 192.168.1.2, PC 192.168.1.3, mask 255.255.255.0). |
| PC on a phone hotspot, mixer on the router | **No** | The hotspot is a separate network. |
| PC on the venue Wi-Fi, mixer on its own router | **No** | Different networks. Add an access point to the mixer's network instead. |

The mixer's IP address is shown on the mixer under **Setup → Network** (DHCP or fixed address).

## Firewall and ports

* Protocol: UDP, port **10023** on the mixer. Fadera uses a random local port for the replies.
* Windows Firewall normally allows the replies to Fadera's own requests. If a third-party firewall blocks them, allow `Fadera.exe` on the network you use with the mixer.

## When the mixer is not found

The Connect window lists the network adapters it searched and explains the most likely cause:

* **"The PC is on a different network"**: connect the PC to the mixer's network (see the table above).
* **"Same network, but the mixer does not answer"**: check that the mixer is on and connected; on some routers Wi-Fi clients are isolated from wired devices (*client isolation*, *AP isolation* or *guest network*). Disable the isolation or use a cable.
* You can always type the IP address manually.

## PC with two networks (Internet + mixer)

You can keep Internet on one adapter (for example USB tethering from a phone or another Ethernet port) and the mixer on another (for example the router's Wi-Fi). Fadera searches on every adapter.
