# Texas Tracker

A static website that tracks our trip to Texas Linux Festival 2025.

## Overview

This repository contains the source code for the Jupiter Broadcasting Texas Tracker; a static website that displays our trip progress to Texas. We use a Nix flake to build a container that runs on our backend, which also runs [dawarich](https://github.com/okteto/dawarich). We report our location to dawarich, and then the container scrapes our point info, accumulates it, and pushes it to an S3 bucket. The `index.html` static site then reads from S3 and displays the tracking information.

You can view the live tracker at [Texas Tracker](https://texastracker.jupiterbroadcasting.com).

## Deployment

The project is deployed using a Nix flake to build a Docker container. The `collector.sh` script is responsible for scraping the location data, accumulating it, and pushing it to S3. The `docker-compose.yml` file is used to run the container.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.
