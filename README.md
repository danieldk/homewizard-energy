# HomeWizard Energy P1 Meter SmartThings Edge Driver

**Warning:** This repository is archived, I do not use SmartThings
anymore. Home Assistant and Homey are _much_ nicer.

This repository provides a SmartThings Edge driver for the [HomeWizard WiFi P1
Meter](https://www.homewizard.com/p1-meter/). This is a smart meter reader that
works with P1 ports (DSMR) on smart meters, which are common in the Netherlands.

The edge driver uses the REST API of the P1 meter that can be used on the local
network.

## Credit

Most credits for this driver go to Todd Austin. This driver is based on his
[Youless Energy Driver](https://github.com/toddaustin07/Youless-Energy-Driver).
I modified it to talk with the HomeWizard API instead.

## Supported metrics

Since we do not have a gas meter or solar panels, only the following metrics are
reported:

- Current total power draw.
- Current total power draw for phases 1, 2, and 3.
- Cumulative power draw.
- Cumulative power draw in tariff 1 and 2.

## Installation

1. [Enable the local API of the P1 meter](https://helpdesk.homewizard.com/en/articles/5935977-integrating-energy-with-other-systems-api)
2. [Enroll in my channel on your hub](https://callaway.smartthings.com/channels/c69b502f-efe4-4b0b-9306-41d8d4ff8c9f)
3. Add a device and search nearby devices.
4. Select the HomeWizard P1 WiFi Meter device.
5. Go to the device settings and set the IP address to the address of the P1 meter.

Of course, if you don't trust third-party channels, you could also check out
this repository, verify the code, and install the driver through your own
channel.
