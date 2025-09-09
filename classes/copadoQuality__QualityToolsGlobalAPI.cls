/*
This file is generated and isn't the actual source code for this
managed global class.
This read-only file shows the class's global constructors,
methods, variables, and properties.
To enable code to compile, all methods return null.
*/
global class QualityToolsGlobalAPI {
    global QualityToolsGlobalAPI() {

    }
    global copadoQuality.QualityToolsGlobalAPI.LicenseInfo getLicenseInformation() {
        return null;
    }
global class LicenseInfo {
    global copado.GlobalAPI.CopadoLicenses CopadoLicense {
        get;
        set;
    }
    global copadoQuality.QualityToolsGlobalAPI.QualityGatesLicense QualityGatesLicense {
        get;
        set;
    }
    global LicenseInfo() {

    }
}
global class QualityGatesLicense {
    global Integer availableExplorerLicenses {
        get;
        set;
    }
    global Integer totalNumberOfExplorerLicenses {
        get;
        set;
    }
    global Integer usedExplorerLicenses {
        get;
        set;
    }
    global QualityGatesLicense() {

    }
}
}
