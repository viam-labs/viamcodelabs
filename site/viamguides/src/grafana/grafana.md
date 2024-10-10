author: Joyce
id: grafana
summary: Visualize air quality sensor data with Grafana
categories: Data, Getting-Started, Developer
environments: web
status: Published
feedback link: https://github.com/viam-devrel/viamcodelabs/issues
tags: Data, Getting Started, Developer

# Visualize sensor data with Grafana

<!-- ------------------------ -->

## Overview

Duration: 1

Let's visualize sensor data in Viam with a third-party tool, such as Grafana. In this tutorial, you'll need a machine connected to the Viam app with a configured sensor component, such as the `pms7003`, to collect air quality measurements, originally captured for our [Automate air filtration with air quality sensors](https://codelabs.viam.com/guide/air-quality/index.html?index=..%2F..index#0) codelab.

![Grafana time series data](assets/grafanaGraph.png)

### Prerequisites

- Familiarity with MQL or SQL queries

### What You’ll Learn

- how to capture sensor data with Viam
- how to set up data management with Viam
- how to visualize sensor data in Viam with a third-party tool, such as Grafana
- how to use the MongoDB plugin with Viam and Grafana
- how to create a Grafana dashboard using the MongoDB data source

### What You’ll Need

- A [Grafana](https://grafana.com/auth/sign-in) instance. You can use either Grafana Cloud or a local instance of Grafana Enterprise. This tutorial will use Grafana Cloud (free trial available).
- A machine connected to [the Viam app](https://app.viam.com) with a configured sensor component, such as the `pms7003` sensor mentioned above.
- Install the [Viam CLI](https://docs.viam.com/cli/#install) to manage your Viam machines and resources from the command line.

### What You’ll Build

- A Grafana dashboard to monitor real-time air quality sensor data with Viam

<!-- ------------------------ -->

## Capture and sync data in Viam

Duration: 3

To capture data from your machine and sync to the Viam app, add the [data management service](https://docs.viam.com/services/data/capture-sync/#configure-data-capture-and-sync) and configure data capture for your sensor component.

### Add the data management service

1. From the [Viam app](https://app.viam.com/), find your active machine and navigate to the **CONFIGURE** tab.
1. Click the **+** icon in the left-hand menu and select **Service**.
   ![select service](assets/addService.png)
1. Select **data management**.
1. Leave the default service name `data_manager-1`, then click **Create**.
   ![add data manager](assets/dataManager.png)
1. On the corrresponding panel that appears, review the default settings to capture data locally and sync captured data files to the Viam app. then click **Save** in the top-right corner of the screen.
   ![capture data](assets/captureData.png)

### Configure data capture for your sensor

Now that you added the data management service, it's time to configure data capture for your sensor so that we can visualize this time-series data.

1. Under the **CONFIGURE** tab in the [Viam app](https://app.viam.com/), find the panel for the configured sensor component.
1. Under the **Data capture** section, click **Add method** to enable data capture for this sensor. Then set the Method to `Readings` and the **Frequency (hz)** to `0.333` to capture data from the sensor device roughly once every 3 seconds.
   ![data capture frequency](assets/dataCaptureFrequency.png)
1. **Save** the configuration changes.
1. Once your sensor starts capturing live readings, and syncing those readings to the Viam app, click on the options menu (**...**), and select **View captured data**.
   ![options menu to view captured data](assets/viewCapturedData.png)
1. Confirm the data is being captured properly.
   ![sensor data](assets/capturedDataLogs.png)

<!-- ------------------------ -->

## Configure data query in Viam

Duration: 3

When you sync captured data to Viam, that data is stored in the Viam organization’s MongoDB Atlas Data Federation instance. [Configuring a data query](https://docs.viam.com/how-tos/sensor-data-query-with-third-party-tools/#configure-data-query) allows you to directly query your data using the Viam app or a compatible client (such as `mongosh` shell or MongoDB Compass), but also allows Grafana to access that data and visualize it.

### Configure data query

To query data from third party tools, let's get the credentials you need to connect to the third party service.

1. From your terminal window, authenticate with the Viam CLI using a personal access token. The following command will open a new browser window with a prompt to complete the authentication process.
   ```bash
   viam login
   ```
1. Find your organization ID to create a database user allowing you to access your data. Make a note of the organization ID containing the active machine with the configured sensor component.
   ```bash
   viam organizations list
   ```
1. Configure a new database user for the Viam organization's MongoDB Atlas Data Federation instance, which is where your machine's synced data is stored. Use your `org-id` from the previous step and a new password for this database user. Your password must be 8 characters long with 1 uppercase and 1 numeric character.
   ```bash
   viam data database configure --org-id=<YOUR-ORGANIZATION-ID> --password=<NEW-DBUSER-PASSWORD>
   ```
   > aside negative
   > This command configures a database user for your organization for use with data query, and sets the password. If you have run this command before, this command instead **_updates_** the password to the new value you set. In other words, changing this password can break existing integrations for your organization.
1. Determine the connection URI for your organization's MongoDB Atlas Data Federation instance, again using your own `org-id` from the previous steps.
   ```bash
   viam data database hostname --org-id=<YOUR-ORGANIZATION-ID>
   ```
   ```bash
   # Example output
    MongoDB Atlas Data Federation instance hostname: data-federation-abcd1e2f-a1b2-3c45-de6f-ab123456c123-0z9yx.a.query.mongodb.net
    MongoDB Atlas Data Federation instance connection URI: mongodb://db-user-abcd1e2f-a1b2-3c45-de6f-ab123456c123:YOUR-PASSWORD-HERE@data-federation-abcd1e2f-a1b2-3c45-de6f-ab123456c123-0z9yx.a.query.mongodb.net/?ssl=true&authSource=admin
   ```
1. Make a note of the **hostname** returned by the previous command and the **password** you chose for that user, so that we can connect to the server and query your data in the next section.
   > aside negative
   > Most MQL-compatible database clients require the connection URI, along with your user credentials, to connect to this server. However, as we will see in the next steps, the MongoDB plugin requires a hostname and database name, along with your user credentials, to connect to the server.

<!-- ------------------------ -->

## Configure the MongoDB data source in Grafana

Duration: 3

> aside negative
> To use the [MongoDB data source plugin for Grafana](https://grafana.com/grafana/plugins/grafana-mongodb-datasource/), you'll need either Grafana Cloud or a local instance of Grafana Enterprise. This tutorial will use Grafana Cloud (free trial version available). Only users with the organization `administrator` role can add data sources.

With your machine capturing data and syncing it to Viam, and direct query of that data configured, you can now configure Grafana to access and visualize that data.

### Add the MongoDB data source in Grafana

Let's set up the [MongoDB data source in Grafana](https://grafana.com/docs/plugins/grafana-mongodb-datasource/latest/configure-mongodb-data-source/)

1. To add the MongoDB data source, click **Connections** in the left-side menu of the Grafana web UI. Then click **Add new connection**.
   ![add connection](assets/grafanaMenu.png)
1. Enter `MongoDB` in the search bar. Select **MongoDB** under the **Data Source** section. Be sure to install the MongoDB _data source_, not the _integration_.
   ![add MongoDB as data source](assets/mongoSearch.png)
1. Click **Add new data source** in the upper right. You will be taken to the **Settings** tab where you will set up your MongoDB configuration.

### Configure the MongoDB data source

1. Under the **Name** section, you can leave the default name. This is how you refer to the data source in panels and queries.
1. Under the **Connection** section, add your **Connection string**, which contains some of the parameters required to connect to MongoDB. Replace `&lt;MONGODB-ATLAS-DF-HOSTNAME&gt;` with your database hostname as configured with the previous steps, and replace `&lt;DATABASE-NAME&gt;` with the desired database name to query. For most use cases with Viam, this database name will be `sensorData`.
   ```bash
   mongodb://<MONGODB-ATLAS-DF-HOSTNAME>/<DATABASE-NAME>?directConnection=true&authSource=admin&tls=true
   ```
1. Under the **Authentication** section, select **Credentials** from the dropdown.
1. Within the **User** field, enter the following username, substituting your organization ID as determined earlier, for `&lt;YOUR-ORG-ID&gt;`.
   ```bash
   db-user-<YOUR-ORG-ID>
   ```
1. Under the **Password** field, enter the password you provided earlier.
   ![configure connection details](assets/connectionConfig.png)
1. At the bottom of the **Settings** page, click **Save & test** to verify the plugin has been set up properly.
   ![save and test](assets/testing.png)

<!-- ------------------------ -->

## Build a Grafana dashboard

Duration: 5

With your data connection established, you can then build dashboards that provide insight into your data.

### Create a new dashboard

1. To [create a new Grafana dashboard on Grafana Cloud](https://grafana.com/docs/grafana-cloud/visualizations/dashboards/build-dashboards/create-dashboard/), click **Dashboards** in the left-side menu of the Grafana web UI. Then click **New**, and select **New dashboard**.
   ![new dashboard](assets/newDash.png)
1. Start your new dashboard by adding a New visualization. Click **+ Add visualization**.
   ![new visualization](assets/newViz.png)
1. Select the name of the data source that you just configured.
   ![select data source](assets/selectDataSource.png)
1. Write or construct a query in the query language of your data source, either SQL or MQL. The following MQL query searches the `sensorData` database and `readings` collection, and gets readings from an air quality sensor called `sensor-1`, filtering on fine particulate matter with a diameter of 2.5 or 10 micrometers.
   ```bash
   sensorData.readings.aggregate([
      { $match: { component_name: "sensor-1" } },
      {
        $project: {
          pm2_5_atm: "$data.readings.pm2_5_atm",
          pm10_atm: "$data.readings.pm10_atm",
          _id: 0,
          time_received: "$time_received"
        }
      }
   ])
   ```
1. Click the **Run query** button, and confirm the time series data displays as you want it to on the graph above.
   ![time series data](assets/queryAndViz.png)
1. Continue editing your query, or add new queries, and then **Save dashboard** when you're done.

<!-- ------------------------ -->

## Next Steps

Duration: 2

Grafana supports the ability to directly [query and transform your data](https://grafana.com/docs/grafana/latest/panels-visualizations/query-transform-data/) within a dashboard to generate more granular visualizations of specific data. You can query your captured data within a Grafana dashboard using either SQL or MQL. See the [guide on querying sensor data](https://docs.viam.com/how-tos/sensor-data-query-with-third-party-tools/) or the [guide on visualizing your data](https://docs.viam.com/tutorials/services/visualize-data-grafana/#visualize-your-data) for more information.

### What You Learned

- how to capture sensor data with Viam
- how to set up data management with Viam
- how to visualize sensor data in Viam with a third-party tool, such as Grafana
- how to use the MongoDB plugin with Viam and Grafana
- how to create a Grafana dashboard using the MongoDB data source

### Related Resources

- VIDEO
- Learn how to [query data with third-party tools](https://docs.viam.com/how-tos/sensor-data-query-with-third-party-tools/#query-data-using-third-party-tools)
- [Automate air filtration with air quality sensors](https://codelabs.viam.com/guide/air-quality/index.html?index=..%2F..index#0) codelab
- [Monitor Air Quality with a Fleet of Sensors](https://docs.viam.com/tutorials/control/air-quality-fleet/) tutorial
  ![fleet management tutorial](assets/dashboard.webp)
