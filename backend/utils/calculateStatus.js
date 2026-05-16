const calculateStatus = (sensorData, thresholds) => {
  const {
    temperature,
    smokeLevel,
    co2Level,
    flameDetected,
  } = sensorData;

  if (
    flameDetected === true ||
    temperature >= thresholds.temperatureDanger ||
    smokeLevel >= thresholds.smokeDanger ||
    co2Level >= thresholds.co2Danger
  ) {
    return "danger";
  }

  if (
    temperature >= thresholds.temperatureWarning ||
    smokeLevel >= thresholds.smokeWarning ||
    co2Level >= thresholds.co2Warning
  ) {
    return "warning";
  }

  return "safe";
};

module.exports = calculateStatus;