author: HipsterBrown
id: pydantic-validation
summary: Use Pydantic models to validate module configuration and environment variables
categories: Developer, Validation, Modules
environments: web
status: Published 
feedback link: https://github.com/viam-labs/viamcodelabs/issues
tags: Modules, Developer, Validation, Intermediate

# Module and environment variable validation with Pydantic
<!-- ------------------------ -->
## Overview 
Duration: 1

The [Viam Python SDK](https://python.viam.dev) is a great way to extend the platform with modules and automate machines with scripts. For each of these tasks, you may encounter the need to validate user-supplied configuration or settings from environment variables. While you can do this manually with simple [`type()`](https://docs.python.org/3/library/functions.html#type) and [`assert`](https://docs.python.org/3/reference/simple_stmts.html#the-assert-statement) checks, there are more robust, type-safe libraries for handling this logic such as [Pydantic](https://docs.pydantic.dev/latest/).

![Pydantic logo text](./assets/pydantic-logo.svg)

Pydantic is the most widely used data validation library for Python; used by HuggingFace, FastAPI, Django, and more.

Building off the [Working with Python environment variables codelab](/guide/environment-variables/index.html), you'll learn about using Pydantic to ensure your Viam machines are configured correctly.

### Prerequisites
- Familiarity with Python

### What You’ll Learn 
- How to validate [modular resource](https://docs.viam.com/registry/#modular-resources) configurations
- How to validate environment variable settings in a Python [process script](https://docs.viam.com/configure/processes/)

### What You’ll Need 
- A computer with MacOS, Windows, or Linux 
- [Python3](https://www.python.org/downloads/) installed on your computer
- [VS Code](https://code.visualstudio.com/download) installed, or another similar code editor of your choice.

### What You’ll Build 
- a [sensor component](https://docs.viam.com/components/sensor/) module with type-safe configuration
- a Python script for automating a Viam machine that uses validated environment variables

<!-- ------------------------ -->
## Create a module project
Duration: 5

In this step, you'll build upon the How-to Guide for [creating a sensor module with Python](https://docs.viam.com/how-tos/sensor-module/) to provide robust, type-safe validation to this configuration logic.

### Set up the Python sensor module project

These instructions will not include the explanations of each file in the module project, see the linked How-to Guide for more of those details. If you use the [module generator](https://docs.viam.com/how-tos/sensor-module/#generate-boilerplate-module-code), you can skip to the 5th instruction in this section.

1. Create the project directory through the command line or using the code editor of your choice:

```console
mkdir open-meteo-module && cd open-meteo-module
```

2. Create the necessary files for the project: `requirements.txt`, `meta.json`, `run.sh`, and `main.py`, using the command line or code editor of your choice:

```console
touch requirements.txt meta.json run.sh main.py
```

3. In the `meta.json`, add the JSON metadata for the module (replacing the "\<namespace\>" with the [public namespace for your Viam organization](https://docs.viam.com/cloud/organizations/#create-a-namespace-for-your-organization) or something random if you don't plan on publishing this):

```json
{
  "$schema": "https://dl.viam.dev/module.schema.json",
  "module_id": "<namespace>:open-meteo",
  "visibility": "public",
  "url": "",
  "description": "Modular sensor component: meteo_pm",
  "models": [
    {
      "api": "rdk:component:sensor",
      "model": "<namespace>:open-meteo:meteo_pm"
    }
  ],
  "entrypoint": "./run.sh"
}
```

4. In the `run.sh`, add the following shell scripting code for running the module script:

```bash
#!/bin/sh
cd `dirname $0`

# Create a virtual environment to run our code
VENV_NAME="venv"
PYTHON="$VENV_NAME/bin/python"

ENV_ERROR="This module requires Python >=3.8, pip, and virtualenv to be installed."

if ! python3 -m venv $VENV_NAME >/dev/null 2>&1; then
    echo "Failed to create virtualenv."
    if command -v apt-get >/dev/null; then
        echo "Detected Debian/Ubuntu, attempting to install python3-venv automatically."
        SUDO="sudo"
        if ! command -v $SUDO >/dev/null; then
            SUDO=""
        fi
		if ! apt info python3-venv >/dev/null 2>&1; then
			echo "Package info not found, trying apt update"
			$SUDO apt -qq update >/dev/null
		fi
        $SUDO apt install -qqy python3-venv >/dev/null 2>&1
        if ! python3 -m venv $VENV_NAME >/dev/null 2>&1; then
            echo $ENV_ERROR >&2
            exit 1
        fi
    else
        echo $ENV_ERROR >&2
        exit 1
    fi
fi

# remove -U if viam-sdk should not be upgraded whenever possible
# -qq suppresses extraneous output from pip
echo "Virtualenv found/created. Installing/upgrading Python packages..."
if ! $PYTHON -m pip install -r requirements.txt -Uqq; then
    exit 1
fi

# Be sure to use `exec` so that termination signals reach the python process,
# or handle forwarding termination signals manually
echo "Starting module..."
exec $PYTHON main.py $@
```

5. In the `requirements.txt`, add the dependencies for the project:

```txt
openmeteo-requests
requests-cache
retry-requests
viam-sdk
pydantic
```

6. In the `main.py`, add the initial sensor module implementation code (replacing \<namespace\> with the same value used in the `meta.json`):

```python
import asyncio
from typing import Any, ClassVar, Mapping, Optional, Sequence
from typing_extensions import Self

from viam.components.sensor import Sensor
from viam.logging import getLogger
from viam.module.module import Module
from viam.proto.app.robot import ComponentConfig
from viam.proto.common import ResourceName
from viam.resource.base import ResourceBase
from viam.resource.easy_resource import EasyResource
from viam.resource.types import Model, ModelFamily
from viam.utils import SensorReading, struct_to_dict

import openmeteo_requests
import requests_cache
from retry_requests import retry

class MeteoPm(Sensor, EasyResource):
    MODEL: ClassVar[Model] = Model(
        ModelFamily("<namespace>", "open-meteo"), "meteo_pm"
    )

    latitude: float
    longitude: float

    @classmethod
    def new(
        cls, config: ComponentConfig, dependencies: Mapping[ResourceName, ResourceBase]
    ) -> Self:
        """This method creates a new instance of this sensor component.
        The default implementation sets the name from the `config` parameter and then calls `reconfigure`.

        Args:
            config (ComponentConfig): The configuration for this resource
            dependencies (Mapping[ResourceName, ResourceBase]): The dependencies (both implicit and explicit)

        Returns:
            Self: The resource
        """
        return super().new(config, dependencies)

    @classmethod
    def validate_config(cls, config: ComponentConfig) -> Sequence[str]:
        """This method allows you to validate the configuration object received from the machine,
        as well as to return any implicit dependencies based on that `config`.

        Args:
            config (ComponentConfig): The configuration for this resource

        Returns:
            Sequence[str]: A list of implicit dependencies
        """
        fields = config.attributes.fields
        # Check that configured fields are floats
        if "latitude" in fields:
            if not fields["latitude"].HasField("number_value"):
                raise Exception("Latitude must be a float.")

        if "longitude" in fields:
            if not fields["longitude"].HasField("number_value"):
                raise Exception("Longitude must be a float.")
        return []

    def reconfigure(
        self, config: ComponentConfig, dependencies: Mapping[ResourceName, ResourceBase]
    ):
        """This method allows you to dynamically update your service when it receives a new `config` object.

        Args:
            config (ComponentConfig): The new configuration
            dependencies (Mapping[ResourceName, ResourceBase]): Any dependencies (both implicit and explicit)
        """
        attrs = struct_to_dict(config.attributes)

        self.latitude = float(attrs.get("latitude", 45))
        LOGGER.debug(f"Using latitude: {self.latitude}")

        self.longitude = float(attrs.get("longitude", -121))
        LOGGER.debug(f"Using longitude: {self.longitude}")

    async def get_readings(
        self,
        *,
        extra: Optional[Mapping[str, Any]] = None,
        timeout: Optional[float] = None,
        **kwargs
    ) -> Mapping[
        str,
        SensorReading,
    ]:
        # Set up the Open-Meteo API client with cache and retry on error
        cache_session = requests_cache.CachedSession(
          '.cache', expire_after=3600)
        retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
        openmeteo = openmeteo_requests.Client(session=retry_session)

        # The order of variables in hourly or daily is
        # important to assign them correctly below
        url = "https://air-quality-api.open-meteo.com/v1/air-quality"
        params = {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "current": ["pm10", "pm2_5"],
            "timezone": "America/Los_Angeles"
        }
        responses = openmeteo.weather_api(url, params=params)

        # Process location
        response = responses[0]

        # Current values. The order of variables needs
        # to be the same as requested.
        current = response.Current()
        current_pm10 = current.Variables(0).Value()
        current_pm2_5 = current.Variables(1).Value()

        LOGGER.info(current_pm2_5)

        # Return a dictionary of the readings
        return {
            "pm2_5": current_pm2_5,
            "pm10": current_pm10
        }


if __name__ == "__main__":
    asyncio.run(Module.run_from_registry())
```

7. Create the Python virtual environment and install the project dependencies:

```console
python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

Those were quite a few steps to get through just to set up the project, so great job sticking with it! Now onto the fun part: validation!

<!-- ------------------------ -->
## Add module configuration validation
Duration: 5

Now that there is a practical project in place, you'll explore how to improve the validation logic and configuration settings with [Pydantic](https://pydantic.dev).

Focusing on the `validate_config` class method first, the `config.attributes.fields` are a mapping of [attributes](https://docs.viam.com/configure/#components) set as JSON in the configuration for each component or service.
These fields can be checked for existence (maybe they're required) and verifying the values for those fields are of a specific type; the current implementation is relatively simple for the two fields being validated.
However, as more configuration attributes are added and extra logic (such as ensuring values are within a certain range), this will become unweildy to maintain.

```python
@classmethod
def validate_config(cls, config: ComponentConfig) -> Sequence[str]:
    """This method allows you to validate the configuration object received from the machine,
    as well as to return any implicit dependencies based on that `config`.

    Args:
        config (ComponentConfig): The configuration for this resource

    Returns:
        Sequence[str]: A list of implicit dependencies
    """
    fields = config.attributes.fields
    # Check that configured fields are floats
    if "latitude" in fields:
        if not fields["latitude"].HasField("number_value"):
            raise Exception("Latitude must be a float.")

    if "longitude" in fields:
        if not fields["longitude"].HasField("number_value"):
            raise Exception("Longitude must be a float.")
    return []

```

Pydantic provides a library of base classes and helper methods for creating intuitive validation models that make use of Python's [type hints](https://docs.python.org/3/glossary.html#term-type-hint).
The same logic in the current `validate_config` class method can be implemented with the following Pydantic model, making use of the handy [`struct_to_dict` utility method](https://python.viam.dev/autoapi/viam/utils/index.html#viam.utils.struct_to_dict) from the Viam Python SDK:

```python
from viam.utils import struct_to_dict
from pydantic import BaseModel

class Config(BaseModel):
    latitude: float = 45
    longitude: float = -121

# in the validate_config method
    Config(**struct_to_dict(config.attributes))
    return []
```

If there are any invalid values (or unknown fields) in the `config.attributes` passed to the `Config` class, then it will raise a custom ValidationError that will be displayed in the Viam logs. The `Config` class also includes the default value logic included in the `reconfigure` method of the module, making it immediately useful for that use case as well.

```python
# in the reconfigure method
    self.config = Config(**struct_to_dict(config.attributes))
    LOGGER.debug(f"Using latitude: {self.config.latitude}")
    LOGGER.debug(f"Using longitude: {self.config.longitude}")
```

Now if there's additional validation logic required for the module configuration, you can add it to the `Config` class:

```python
from pydantic import BaseModel, Field

class Config(BaseModel):
    latitude: float = Field(ge=-90, le=90, default=45)
    longitude: float = Field(ge=-180, le=180, default=-121)
```

Now the validation uses [numeric constraints](https://docs.pydantic.dev/latest/concepts/fields/#numeric-constraints) to check that the latitude is between -90 and 90 and longitude is between -180 and 180.

The final module class shook look like this:

```python
import asyncio
from typing import Any, ClassVar, Mapping, Optional, Sequence
from typing_extensions import Self

from viam.components.sensor import Sensor
from viam.logging import getLogger
from viam.module.module import Module
from viam.proto.app.robot import ComponentConfig
from viam.proto.common import ResourceName
from viam.resource.base import ResourceBase
from viam.resource.easy_resource import EasyResource
from viam.resource.types import Model, ModelFamily
from viam.utils import SensorReading, struct_to_dict

import openmeteo_requests
import requests_cache
from retry_requests import retry

from pydantic import BaseModel, Field

class Config(BaseModel):
    latitude: float = Field(ge=-90, le=90, default=45)
    longitude: float = Field(ge=-180, le=180, default=-121)

class MeteoPm(Sensor, EasyResource):
    MODEL: ClassVar[Model] = Model(
        ModelFamily("<namespace>", "open-meteo"), "meteo_pm"
    )

    config: Config

    @classmethod
    def new(
        cls, config: ComponentConfig, dependencies: Mapping[ResourceName, ResourceBase]
    ) -> Self:
        """This method creates a new instance of this sensor component.
        The default implementation sets the name from the `config` parameter and then calls `reconfigure`.

        Args:
            config (ComponentConfig): The configuration for this resource
            dependencies (Mapping[ResourceName, ResourceBase]): The dependencies (both implicit and explicit)

        Returns:
            Self: The resource
        """
        return super().new(config, dependencies)

    @classmethod
    def validate_config(cls, config: ComponentConfig) -> Sequence[str]:
        """This method allows you to validate the configuration object received from the machine,
        as well as to return any implicit dependencies based on that `config`.

        Args:
            config (ComponentConfig): The configuration for this resource

        Returns:
            Sequence[str]: A list of implicit dependencies
        """
        Config(**struct_to_dict(config.attributes))
        return []

    def reconfigure(
        self, config: ComponentConfig, dependencies: Mapping[ResourceName, ResourceBase]
    ):
        """This method allows you to dynamically update your service when it receives a new `config` object.

        Args:
            config (ComponentConfig): The new configuration
            dependencies (Mapping[ResourceName, ResourceBase]): Any dependencies (both implicit and explicit)
        """
        self.config = Config(**struct_to_dict(config.attributes))
        LOGGER.debug(f"Using latitude: {self.config.latitude}")
        LOGGER.debug(f"Using longitude: {self.config.longitude}")

    async def get_readings(
        self,
        *,
        extra: Optional[Mapping[str, Any]] = None,
        timeout: Optional[float] = None,
        **kwargs
    ) -> Mapping[
        str,
        SensorReading,
    ]:
        # Set up the Open-Meteo API client with cache and retry on error
        cache_session = requests_cache.CachedSession(
          '.cache', expire_after=3600)
        retry_session = retry(cache_session, retries=5, backoff_factor=0.2)
        openmeteo = openmeteo_requests.Client(session=retry_session)

        # The order of variables in hourly or daily is
        # important to assign them correctly below
        url = "https://air-quality-api.open-meteo.com/v1/air-quality"
        params = {
            "latitude": self.config.latitude,
            "longitude": self.config.longitude,
            "current": ["pm10", "pm2_5"],
            "timezone": "America/Los_Angeles"
        }
        responses = openmeteo.weather_api(url, params=params)

        # Process location
        response = responses[0]

        # Current values. The order of variables needs
        # to be the same as requested.
        current = response.Current()
        current_pm10 = current.Variables(0).Value()
        current_pm2_5 = current.Variables(1).Value()

        LOGGER.info(current_pm2_5)

        # Return a dictionary of the readings
        return {
            "pm2_5": current_pm2_5,
            "pm10": current_pm10
        }


if __name__ == "__main__":
    asyncio.run(Module.run_from_registry())
```

<!-- ------------------------ -->
## Create Python control script
Duration: 2

<!-- ------------------------ -->
## Add environment variable validation
Duration: 4

<!-- ------------------------ -->
## Conclusion And Resources
Duration: 1

TBD

### What You Learned
- creating steps and setting duration
- adding code snippets
- embedding images, videos, and surveys
- importing other markdown files

### Related Resources
- <link to github code repo>
- <link to documentation>
