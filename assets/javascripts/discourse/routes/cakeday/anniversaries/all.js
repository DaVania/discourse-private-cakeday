import buildCakedayRoute from "discourse/plugins/discourse-private-cakeday/discourse/routes/build-cakeday-route";

export default buildCakedayRoute("anniversary").extend({
  queryParams: {
    month: { refreshModel: true },
  },

  refreshQueryWithoutTransition: true,
});
