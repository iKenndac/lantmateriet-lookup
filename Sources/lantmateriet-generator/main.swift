#!/usr/bin/swift

//
//  main.swift
//  lantmateriet-generator
//
//  Created by Daniel Kennett on 2018-10-28.
//  Copyright © 2018 Daniel Kennett. All rights reserved.
//

import Foundation
import ImageIO
import CoreLocation
import Utility
import Basic

// MARK: - WGS84 <-> UTM Conversion

// Code ported from the JavaScript at http://home.hiwaay.net/~taylorc/toolbox/geography/geoutm.html

/* Ellipsoid model constants (actual values here are for WGS84) */
let sm_a: Double = 6378137.0
let sm_b: Double = 6356752.314
let sm_EccSquared: Double = 6.69437999013e-03

let utmScaleFactor: Double = 0.9996

/*
 * ArcLengthOfMeridian
 *
 * Computes the ellipsoidal distance from the equator to a point at a
 * given latitude.
 *
 * Reference: Hoffmann-Wellenhof, B., Lichtenegger, H., and Collins, J.,
 * GPS: Theory and Practice, 3rd ed.  New York: Springer-Verlag Wien, 1994.
 *
 * Inputs:
 *     phi - Latitude of the point, in radians.
 *
 * Globals:
 *     sm_a - Ellipsoid model major axis.
 *     sm_b - Ellipsoid model minor axis.
 *
 * Returns:
 *     The ellipsoidal distance of the point from the equator, in meters.
 *
 */
func arcLengthOfMeridian(phi: Double) -> Double {
    /* Precalculate n */
    let n = (sm_a - sm_b) / (sm_a + sm_b)

    /* Precalculate alpha */
    let alpha = ((sm_a + sm_b) / 2.0)
        * (1.0 + (pow(n, 2.0) / 4.0) + (pow(n, 4.0) / 64.0))

    /* Precalculate beta */
    let beta = (-3.0 * n / 2.0) + (9.0 * pow(n, 3.0) / 16.0)
        + (-3.0 * pow(n, 5.0) / 32.0)

    /* Precalculate gamma */
    let gamma = (15.0 * pow(n, 2.0) / 16.0)
        + (-15.0 * pow(n, 4.0) / 32.0)

    /* Precalculate delta */
    let delta = (-35.0 * pow(n, 3.0) / 48.0)
        + (105.0 * pow(n, 5.0) / 256.0)

    /* Precalculate epsilon */
    let epsilon = (315.0 * pow(n, 4.0) / 512.0)

    /* Now calculate the sum of the series and return */
    return alpha * (phi + (beta * sin(2.0 * phi))
            + (gamma * sin(4.0 * phi))
            + (delta * sin(6.0 * phi))
            + (epsilon * sin(8.0 * phi)))
}

/*
 * UTMCentralMeridian
 *
 * Determines the central meridian for the given UTM zone.
 *
 * Inputs:
 *     zone - An integer value designating the UTM zone, range [1,60].
 *
 * Returns:
 *   The central meridian for the given UTM zone, in radians, or zero
 *   if the UTM zone parameter is outside the range [1,60].
 *   Range of the central meridian is the radian equivalent of [-177,+177].
 *
 */
func utmCentralMeridian(zone: Int) -> Double {
    return (-183.0 + (Double(zone) * 6.0)).inRadians
}

/*
 * FootpointLatitude
 *
 * Computes the footpoint latitude for use in converting transverse
 * Mercator coordinates to ellipsoidal coordinates.
 *
 * Reference: Hoffmann-Wellenhof, B., Lichtenegger, H., and Collins, J.,
 *   GPS: Theory and Practice, 3rd ed.  New York: Springer-Verlag Wien, 1994.
 *
 * Inputs:
 *   y - The UTM northing coordinate, in meters.
 *
 * Returns:
 *   The footpoint latitude, in radians.
 *
 */
func footpointLatitude(y: Double) -> Double {

    /* Precalculate n (Eq. 10.18) */
    let n = (sm_a - sm_b) / (sm_a + sm_b)

    /* Precalculate alpha_ (Eq. 10.22) */
    /* (Same as alpha in Eq. 10.17) */
    let alpha_ = ((sm_a + sm_b) / 2.0)
        * (1 + (pow(n, 2.0) / 4) + (pow(n, 4.0) / 64))

    /* Precalculate y_ (Eq. 10.23) */
    let y_ = y / alpha_

    /* Precalculate beta_ (Eq. 10.22) */
    let beta_ = (3.0 * n / 2.0) + (-27.0 * pow(n, 3.0) / 32.0)
        + (269.0 * pow(n, 5.0) / 512.0)

    /* Precalculate gamma_ (Eq. 10.22) */
    let gamma_ = (21.0 * pow(n, 2.0) / 16.0)
        + (-55.0 * pow(n, 4.0) / 32.0)

    /* Precalculate delta_ (Eq. 10.22) */
    let delta_ = (151.0 * pow(n, 3.0) / 96.0)
        + (-417.0 * pow(n, 5.0) / 128.0)

    /* Precalculate epsilon_ (Eq. 10.22) */
    let epsilon_ = (1097.0 * pow(n, 4.0) / 512.0)

    /* Now calculate the sum of the series (Eq. 10.21) */
    return y_ + (beta_ * sin (2.0 * y_))
        + (gamma_ * sin(4.0 * y_))
        + (delta_ * sin(6.0 * y_))
        + (epsilon_ * sin(8.0 * y_))
}

/*
 * MapLatLonToXY
 *
 * Converts a latitude/longitude pair to x and y coordinates in the
 * Transverse Mercator projection.  Note that Transverse Mercator is not
 * the same as UTM a scale factor is required to convert between them.
 *
 * Reference: Hoffmann-Wellenhof, B., Lichtenegger, H., and Collins, J.,
 * GPS: Theory and Practice, 3rd ed.  New York: Springer-Verlag Wien, 1994.
 *
 * Inputs:
 *    phi - Latitude of the point, in radians.
 *    lambda - Longitude of the point, in radians.
 *    lambda0 - Longitude of the central meridian to be used, in radians.
 *
 * Outputs:
 *    xy - A 2-element array containing the x and y coordinates
 *         of the computed point.
 *
 * Returns:
 *    The function does not return a value.
 *
 */
func mapLatLonToXY (phi: Double, lambda: Double, lambda0: Double) -> (x: Double, y: Double)
{
    /* Precalculate ep2 */
    let ep2 = (pow(sm_a, 2.0) - pow(sm_b, 2.0)) / pow(sm_b, 2.0)

    /* Precalculate nu2 */
    let nu2 = ep2 * pow(cos(phi), 2.0)

    /* Precalculate N */
    let N = pow(sm_a, 2.0) / (sm_b * sqrt(1 + nu2))

    /* Precalculate t */
    let t = tan(phi)
    let t2 = t * t

    /* Precalculate l */
    let l = lambda - lambda0

    /* Precalculate coefficients for l**n in the equations below
     so a normal human being can read the expressions for easting
     and northing
     -- l**1 and l**2 have coefficients of 1.0 */
    let l3coef = 1.0 - t2 + nu2

    let l4coef = 5.0 - t2 + 9 * nu2 + 4.0 * (nu2 * nu2)

    let l5coef = 5.0 - 18.0 * t2 + (t2 * t2) + 14.0 * nu2
        - 58.0 * t2 * nu2

    let l6coef = 61.0 - 58.0 * t2 + (t2 * t2) + 270.0 * nu2
        - 330.0 * t2 * nu2

    let l7coef = 61.0 - 479.0 * t2 + 179.0 * (t2 * t2) - (t2 * t2 * t2)

    let l8coef = 1385.0 - 3111.0 * t2 + 543.0 * (t2 * t2) - (t2 * t2 * t2)

    var result = (0.0, 0.0)

    /* Calculate easting (x) */
    result.0 = N * cos(phi) * l
        + (N / 6.0 * pow(cos(phi), 3.0) * l3coef * pow(l, 3.0))
        + (N / 120.0 * pow(cos(phi), 5.0) * l5coef * pow(l, 5.0))
        + (N / 5040.0 * pow(cos(phi), 7.0) * l7coef * pow(l, 7.0))

    /* Calculate northing (y) */
    result.1 = arcLengthOfMeridian(phi: phi)
        + (t / 2.0 * N * pow(cos(phi), 2.0) * pow(l, 2.0))
        + (t / 24.0 * N * pow(cos(phi), 4.0) * l4coef * pow(l, 4.0))
        + (t / 720.0 * N * pow(cos(phi), 6.0) * l6coef * pow(l, 6.0))
        + (t / 40320.0 * N * pow(cos(phi), 8.0) * l8coef * pow(l, 8.0))

    return result
}

/*
 * MapXYToLatLon
 *
 * Converts x and y coordinates in the Transverse Mercator projection to
 * a latitude/longitude pair.  Note that Transverse Mercator is not
 * the same as UTM a scale factor is required to convert between them.
 *
 * Reference: Hoffmann-Wellenhof, B., Lichtenegger, H., and Collins, J.,
 *   GPS: Theory and Practice, 3rd ed.  New York: Springer-Verlag Wien, 1994.
 *
 * Inputs:
 *   x - The easting of the point, in meters.
 *   y - The northing of the point, in meters.
 *   lambda0 - Longitude of the central meridian to be used, in radians.
 *
 * Outputs:
 *   philambda - A 2-element containing the latitude and longitude
 *               in radians.
 *
 * Returns:
 *   The function does not return a value.
 *
 * Remarks:
 *   The local variables Nf, nuf2, tf, and tf2 serve the same purpose as
 *   N, nu2, t, and t2 in MapLatLonToXY, but they are computed with respect
 *   to the footpoint latitude phif.
 *
 *   x1frac, x2frac, x2poly, x3poly, etc. are to enhance readability and
 *   to optimize computations.
 *
 */
func mapXYToLatLon(x: Double, y: Double, lambda0: Double) -> (lat: Double, lon: Double)
{
    /* Get the value of phif, the footpoint latitude. */
    let phif = footpointLatitude(y: y)

    /* Precalculate ep2 */
    let ep2 = (pow(sm_a, 2.0) - pow(sm_b, 2.0))
        / pow(sm_b, 2.0)

    /* Precalculate cos (phif) */
    let cf = cos(phif)

    /* Precalculate nuf2 */
    let nuf2 = ep2 * pow(cf, 2.0)

    /* Precalculate Nf and initialize Nfpow */
    let Nf = pow(sm_a, 2.0) / (sm_b * sqrt(1 + nuf2))
    var Nfpow = Nf

    /* Precalculate tf */
    let tf = tan(phif)
    let tf2 = tf * tf
    let tf4 = tf2 * tf2

    /* Precalculate fractional coefficients for x**n in the equations
     below to simplify the expressions for latitude and longitude. */
    let x1frac = 1.0 / (Nfpow * cf)

    Nfpow *= Nf   /* now equals Nf**2) */
    let x2frac = tf / (2.0 * Nfpow)

    Nfpow *= Nf   /* now equals Nf**3) */
    let x3frac = 1.0 / (6.0 * Nfpow * cf)

    Nfpow *= Nf   /* now equals Nf**4) */
    let x4frac = tf / (24.0 * Nfpow)

    Nfpow *= Nf   /* now equals Nf**5) */
    let x5frac = 1.0 / (120.0 * Nfpow * cf)

    Nfpow *= Nf   /* now equals Nf**6) */
    let x6frac = tf / (720.0 * Nfpow)

    Nfpow *= Nf   /* now equals Nf**7) */
    let x7frac = 1.0 / (5040.0 * Nfpow * cf)

    Nfpow *= Nf   /* now equals Nf**8) */
    let x8frac = tf / (40320.0 * Nfpow)

    /* Precalculate polynomial coefficients for x**n.
     -- x**1 does not have a polynomial coefficient. */
    let x2poly = -1.0 - nuf2

    let x3poly = -1.0 - 2 * tf2 - nuf2

    let x4poly = 5.0 + 3.0 * tf2 + 6.0 * nuf2 - 6.0 * tf2 * nuf2
        - 3.0 * (nuf2 * nuf2) - 9.0 * tf2 * (nuf2 * nuf2)

    let x5poly = 5.0 + 28.0 * tf2 + 24.0 * tf4 + 6.0 * nuf2 + 8.0 * tf2 * nuf2

    let x6poly = -61.0 - 90.0 * tf2 - 45.0 * tf4 - 107.0 * nuf2
        + 162.0 * tf2 * nuf2

    let x7poly = -61.0 - 662.0 * tf2 - 1320.0 * tf4 - 720.0 * (tf4 * tf2)

    let x8poly = 1385.0 + 3633.0 * tf2 + 4095.0 * tf4 + 1575 * (tf4 * tf2)

    var result = (0.0, 0.0)

    /* Calculate latitude */
    result.0 = phif + x2frac * x2poly * (x * x)
        + x4frac * x4poly * pow(x, 4.0)
        + x6frac * x6poly * pow(x, 6.0)
        + x8frac * x8poly * pow(x, 8.0)

    /* Calculate longitude */
    result.1 = lambda0 + x1frac * x
        + x3frac * x3poly * pow(x, 3.0)
        + x5frac * x5poly * pow(x, 5.0)
        + x7frac * x7poly * pow(x, 7.0)

    return result
}

/*
 * LatLonToUTMXY
 *
 * Converts a latitude/longitude pair to x and y coordinates in the
 * Universal Transverse Mercator projection.
 *
 * Inputs:
 *   lat - Latitude of the point, in radians.
 *   lon - Longitude of the point, in radians.
 *   zone - UTM zone to be used for calculating values for x and y.
 *          If zone is less than 1 or greater than 60, the routine
 *          will determine the appropriate zone from the value of lon.
 *
 * Outputs:
 *   xy - A 2-element array where the UTM x and y values will be stored.
 *
 * Returns:
 *   The UTM zone used for calculating the values of x and y.
 *
 */
func latLonToUTMXY(lat: Double, lon: Double, zone: Int) -> (zone: Int, x: Double, y: Double)
{
    let xy = mapLatLonToXY(phi: lat, lambda: lon, lambda0: utmCentralMeridian(zone: zone))

    var result = (zone, 0.0, 0.0)

    /* Adjust easting and northing for UTM system. */
    result.1 = xy.x * utmScaleFactor + 500000.0
    result.2 = xy.y * utmScaleFactor
    if result.2 < 0.0 {
        result.2 = result.2 + 10000000.0
    }

    return result
}

/*
 * UTMXYToLatLon
 *
 * Converts x and y coordinates in the Universal Transverse Mercator
 * projection to a latitude/longitude pair.
 *
 * Inputs:
 *    x - The easting of the point, in meters.
 *    y - The northing of the point, in meters.
 *    zone - The UTM zone in which the point lies.
 *    southhemi - True if the point is in the southern hemisphere;
 *               false otherwise.
 *
 * Outputs:
 *    latlon - A 2-element array containing the latitude and
 *            longitude of the point, in radians.
 *
 * Returns:
 *    The function does not return a value.
 *
 */
func utmXYToLatLon(x: Double, y: Double, zone: Int, southhemi: Bool) -> (lat: Double, lon: Double)
{
    var y = y
    var x = x - 500000.0
    x /= utmScaleFactor

    /* If in southern hemisphere, adjust y accordingly. */
    if (southhemi) {
        y -= 10000000.0
    }

    y /= utmScaleFactor

    let cmeridian = utmCentralMeridian(zone: zone)
    let result = mapXYToLatLon(x: x, y: y, lambda0: cmeridian)
    return (result.lat.inDegrees, result.lon.inDegrees)
}

func gpsToUTM(lat: Double, lon: Double, zone: Int? = nil) -> (zone: Int, southernHemisphere: Bool, x: Double, y: Double) {
    let zoneForConversion = zone ?? Int(floor((lon + 180.0) / 6.0)) + 1
    let result = latLonToUTMXY(lat: lat.inRadians, lon: lon.inRadians, zone: zoneForConversion)
    return (zoneForConversion, lat < 0.0, result.x, result.y)
}

func utmToGPS(x: Double, y: Double, zone: Int, southernHemisphere: Bool) -> (lat: Double, lon: Double) {
    return utmXYToLatLon(x: x, y: y, zone: zone, southhemi: southernHemisphere)
}

extension Double {
    var inRadians: Double {
        return self / 180.0 * .pi
    }

    var inDegrees: Double {
        return self / .pi * 180.0
    }
}

//MARK: - SWEREF 99 TM

struct SWEREFCoordinate: CustomStringConvertible {

    // A SWEREF 99 corrdinate is a UTM coordinate that stretches zone 33's projection
    // to the whole width of Sweden. In the base UTM system, Sweden spans zones 32...35.
    static let utmZone: Int = 33

    let x: Double
    let y: Double

    var wgsCoordinate: CLLocation {
        let wgs = utmToGPS(x: x, y: y, zone: SWEREFCoordinate.utmZone, southernHemisphere: false)
        return CLLocation(latitude: wgs.lat, longitude: wgs.lon)
    }

    var description: String {
        return String(format: "N %1.3f, E %1.3f", y, x)
    }

    var lantmaterietUrl: Foundation.URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "kso.etjanster.lantmateriet.se"
        components.queryItems = [
            URLQueryItem(name: "e", value: "\(Int(x))"),
            URLQueryItem(name: "n", value: "\(Int(y))"),
            URLQueryItem(name: "z", value: "11"),
            URLQueryItem(name: "profile", value: "default_background_noauth")
        ]
        return components.url!
    }

}

extension CLLocation {
    var SWEREF: SWEREFCoordinate? {
        let utm = gpsToUTM(lat: coordinate.latitude, lon: coordinate.longitude, zone: SWEREFCoordinate.utmZone)
        guard utm.southernHemisphere == false else { return nil }
        return SWEREFCoordinate(x: utm.x, y: utm.y)
    }

    var googleMapsUrl: Foundation.URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "www.google.com"
        components.path = "/maps/place/\(coordinate.latitude),\(coordinate.longitude)"
        return components.url!
    }
}

// MARK: - ImageIO

func geotag(inImageAt url: Foundation.URL) -> CLLocation? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: AnyObject] else { return nil }

    guard let gpsInfo = imageProperties[kCGImagePropertyGPSDictionary as String] as? [String : Any] else {
        return nil
    }

    guard var lat = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
        var lon = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
    }

    guard let latRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
        let lonRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
    }

    if latRef == "S" { lat *= -1.0 }
    if lonRef == "W" { lon *= -1.0 }

    return CLLocation(latitude: lat, longitude: lon)
}

// MARK: - Output

func printUser(_ str: String) {
    stderrStream.write(str + "\n")
    stderrStream.flush()
}

func printResult(_ str: String) {
    stdoutStream.write(str + "\n")
    stdoutStream.flush()
}

// MARK: - Lantmäteriet Lookup

enum LantmaterietLookupResult {
    case invalidLocalState
    case requestError(error: Error?)
    case success(kommun: String?, fastighetsbeteckning: String?)
}

func lantmaterietLookup(for swerefCoordinate: SWEREFCoordinate) -> LantmaterietLookupResult {

    let lookupUrl = URL(string: "https://kso.etjanster.lantmateriet.se/sercxi-fastighet/registerenhetsreferensV2?buffer=1")!

    let request = NSMutableURLRequest(url: lookupUrl, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 5.0)
    request.httpMethod = "POST"
    request.setValue("application/text", forHTTPHeaderField: "Content-Type")

    let requestPayload: [String: Any] = ["type": "Point", "coordinates": [swerefCoordinate.x, swerefCoordinate.y]]
    guard let body = try? JSONSerialization.data(withJSONObject: requestPayload, options: []) else {
        printUser("Couldn't encode JSON")
        return .invalidLocalState
    }

    request.httpBody = body
    var response: URLResponse?
    let responseData: Data
    do {
        try responseData = NSURLConnection.sendSynchronousRequest(request as URLRequest, returning: &response)
    } catch let e {
        return .requestError(error: e)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        printUser("Got invalid response from Läntmateriet")
        return .requestError(error: nil)
    }

    guard httpResponse.statusCode == 200 else {
        printUser("Got error code: \(httpResponse.statusCode) from Läntmateriet")
        return .requestError(error: nil)
    }

    guard let responseBody = try? JSONSerialization.jsonObject(with: responseData, options: []) else {
        printUser("Response from Läntmateriet isn't JSON")
        return .requestError(error: nil)
    }

    guard let outerArray = responseBody as? [Any] else {
        printUser("Response from Läntmateriet not as expected")
        return .requestError(error: nil)
    }

    if outerArray.count == 0 {
        // If Läntmateriet doesn't have a database entry for the point, it'll return an empty array.
        return .success(kommun: nil, fastighetsbeteckning: nil)
    }

    guard let dictionary = outerArray.first as? [String: Any] else {
        printUser("Response from Läntmateriet not as expected")
        return .requestError(error: nil)
    }

    let kommun = dictionary["registeromrade"] as? String
    var fastighetsbeteckning: String? = nil
    if let trakt = dictionary["trakt"] as? String,
        let block = dictionary["block"] as? String,
        let enhet = dictionary["enhet"] as? String {
        fastighetsbeteckning = "\(trakt) \(block):\(enhet)"
    } else if let trakt = dictionary["trakt"] as? String,
        let enhet = dictionary["enhet"] as? String {
        // It's valid to not have a block.
        fastighetsbeteckning = "\(trakt) \(enhet)"
    }

    return .success(kommun: kommun, fastighetsbeteckning: fastighetsbeteckning)
}

// MARK: - Geocoding

enum GeocodeResult {
    case success(result: String)
    case lowAccuracyResult(result: String)
    case failure
}

func reverseGeocode(for location: CLLocation) -> GeocodeResult {
    let geocoder = CLGeocoder()
    let sweden = Locale(identifier: "se")
    var result: GeocodeResult = .failure

    guard #available(OSX 10.13, *, *) else {
        return result
    }

    geocoder.reverseGeocodeLocation(location, preferredLocale: sweden) { placemarks, error in
        if let error = error as? CLError {
            switch error.code {
            case .network: printUser("Lookup failed due to no network connection or rate limiting.")
            case .geocodeFoundNoResult: printUser("Reverse geocode got no result!")
            case .geocodeFoundPartialResult: printUser("Reverse geocode got partial result!")
            default: printUser("Reverse geocode got error: \(error.code)")
            }
            result = .failure
        } else if let placemark = placemarks?.first {
            // Admin area: Stockholms län
            // Sub admin area: Botkyrka
            // Name: Stora nygatan 26
            // Locality: Botkyrka
            // Sublocality: Norsborg
            // Thoroughfare: Stora nygatan
            // SubThoroughfare: 26

            if let sub = placemark.subThoroughfare, let thorough = placemark.thoroughfare {
                // Street name and number
                result = .success(result: "\(thorough) \(sub)")
            } else if let thorough = placemark.thoroughfare, let admin = placemark.subAdministrativeArea {
                result = .success(result: "\(thorough), \(admin)")
            } else if let thorough = placemark.thoroughfare {
                result = .success(result: thorough)
            } else if let local = placemark.locality {
                result = .lowAccuracyResult(result: local)
            }
        } else {
            result = .failure
        }
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    // Our Geocoder uses async callbacks to the main queue, so we need to run the runloop
    // to allow that to happen. The callback will stop the runloop so we can carry on.
    CFRunLoopRun()
    return result
}

// MARK: - Script

struct LantmaterietImageEntry {
    let filename: String
    let coordinate: CLLocation?
    var swerefCoordinate: SWEREFCoordinate?
    var streetAddress: String?
    var streetAddressIsLowAccuracy: Bool = false
    var kommun: String?
    var fastighetsbeteckning: String?

    init(filename: String, coordinate: CLLocation?) {
        self.filename = filename
        self.coordinate = coordinate
    }

    static func plainTextOutputColumnTitles(includingUrls: Bool) -> [String] {
        var titles = ["File", "Street Address", "Kommun", "Fastighetsbeteckning", "WGS84 Coordinate", "SWEREF Coordinate"]
        if includingUrls { titles.append(contentsOf: ["Google Maps URL", "Lantmäteriet URL"]) }
        return titles
    }

    func plainTextOutputColumns(includingUrls: Bool) -> [String] {
        var columns = [String]()
        columns.append(filename)

        // Street address
        if let streetAddr = streetAddress {
            if streetAddressIsLowAccuracy {
                columns.append("\(streetAddr)*")
            } else {
                columns.append(streetAddr)
            }
        } else {
            columns.append("(Missing)")
        }

        // Kommun
        if let kommun = kommun {
            columns.append(kommun)
        } else {
            columns.append("(Missing)")
        }

        // Fastighetsbeteckning
        if let fast = fastighetsbeteckning {
            columns.append(fast)
        } else {
            columns.append("(Missing)")
        }

        if let coord = coordinate {
            columns.append(String(format: "%1.7f N, %1.7f E", coord.coordinate.latitude, coord.coordinate.longitude))
        } else {
            columns.append("(Missing)")
        }

        if let coord = swerefCoordinate {
            columns.append(coord.description)
        } else {
            columns.append("(Missing)")
        }

        if includingUrls {
            if let url = coordinate?.googleMapsUrl {
                columns.append(url.absoluteString)
            } else {
                columns.append("(Missing)")
            }

            if let url = swerefCoordinate?.lantmaterietUrl {
                columns.append(url.absoluteString)
            } else {
                columns.append("(Missing)")
            }
        }

        return columns
    }
}

let arguments = ProcessInfo.processInfo.arguments.dropFirst()

let parser = ArgumentParser(usage: "<options>", overview: "Generate a dataset for Lantmäteriet approval of the given images.")
let pathsArgument = parser.add(option: "--images", shortName: "-i", kind: [String].self, strategy: ArrayParsingStrategy.upToNextOption,
                               usage: "The images to look up.")
let textOutputArgument = parser.add(option: "--tsvOutput", shortName: "-t", kind: String.self, usage: "Path for plain text (.tsv) output.")
let htmlOutputArgument = parser.add(option: "--htmlOutput", shortName: "-h", kind: String.self, usage: "Path for HTML output.")
let includeUrlsArgument = parser.add(option: "--includeUrls", shortName: "-u", kind: Bool.self, usage: "Includes manual lookup URLs in plain text output.")
let verboseArgument = parser.add(option: "--verbose", shortName: "-v", kind: Bool.self, usage: "Prints extra output.")

let paths: [String]
let verbose: Bool
let includeUrls: Bool
let textOutputPath: String?
let htmlOutputPath: String?

do {
    let parsedArguments = try parser.parse(Array(arguments))
    verbose = parsedArguments.get(verboseArgument) ?? false
    includeUrls = parsedArguments.get(includeUrlsArgument) ?? false
    paths = parsedArguments.get(pathsArgument) ?? []
    textOutputPath = parsedArguments.get(textOutputArgument)
    htmlOutputPath = parsedArguments.get(htmlOutputArgument)
} catch let error as ArgumentParserError {
    printUser(error.description)
    exit(1)
} catch let error {
    printUser(error.localizedDescription)
    exit(1)
}

guard paths.count > 0 else {
    parser.printUsage(on: stdoutStream)
    exit(1)
}

let urls = paths.compactMap({ URL(fileURLWithPath: $0) })
var entries = [LantmaterietImageEntry]()

for (index, url) in urls.enumerated() {
    let filename = url.lastPathComponent

    guard let gps = geotag(inImageAt: url) else {
        printUser("No geotag present in \(filename)")
        entries.append(LantmaterietImageEntry(filename: filename, coordinate: nil))
        continue
    }

    var entry = LantmaterietImageEntry(filename: filename, coordinate: gps)
    printUser("Performing lookups for \(filename) (\(index + 1) of \(urls.count))…")

    guard let sweRef = gps.SWEREF else {
        printUser("Couldn't convert coordinate to SWEREF")
        continue
    }

    entry.swerefCoordinate = sweRef

    let gpsRoundTrip = sweRef.wgsCoordinate
    let allowableError: CLLocationDistance = 0.1
    guard gpsRoundTrip.distance(from: gps) <= allowableError else {
        printUser("Coordinate conversions gave too big an error!")
        continue
    }

    if verbose {
        printUser("WGS84 coordinate of \(filename) is \(gps.coordinate)")
        printUser("SWEREF coordinate of \(filename) is \(sweRef)")
    }

    switch lantmaterietLookup(for: sweRef) {
    case .invalidLocalState: printUser("Internal error when building request")
    case .requestError(let error): printUser("Error making request: \(String(describing: error))")
    case .success(let kommun, let fastighetsbeteckning):
        if verbose {
            if kommun == nil || fastighetsbeteckning == nil {
                printUser("Lantmäteriet lookup for \(filename) was low-accuracy!")
            } else  {
                printUser("Lantmäteriet lookup for \(filename) got kommun: \(kommun!), fast.: \(fastighetsbeteckning!)")
            }
        }
        entry.kommun = kommun
        entry.fastighetsbeteckning = fastighetsbeteckning
    }

    switch reverseGeocode(for: gps) {
    case .success(let result):
        entry.streetAddress = result
        if verbose { printUser("Reverse geocode for \(filename) got \(result)") }
    case .lowAccuracyResult(let result):
        entry.streetAddress = result
        entry.streetAddressIsLowAccuracy = true
        if verbose { printUser("Reverse geocode for \(filename) got low-accuracy result \(result)") }
    case .failure:
        printUser("Reverse-geocode for \(filename) failed. Check network, or you might have been rate limited!")
    }

    entries.append(entry)

    // All of the web APIs we're using are prone to rate limiting. Wait a little bit, to be nice.
    Thread.sleep(forTimeInterval: 0.5)
    if verbose { printUser("======================") }
}

if let tsvPath = textOutputPath {
    let expandedPath = (tsvPath as NSString).expandingTildeInPath
    var lines: [String] = [LantmaterietImageEntry.plainTextOutputColumnTitles(includingUrls: includeUrls).joined(separator: "\t")]
    lines.append(contentsOf: entries.compactMap({ $0.plainTextOutputColumns(includingUrls: includeUrls).joined(separator: "\t") }))
    let data = lines.joined(separator: "\n").data(using: .utf8)!
    do {
        try data.write(to: URL(fileURLWithPath: expandedPath))
    } catch {
        printUser("Writing to \(tsvPath) failed: \(error)")
    }
}

if let htmlPath = htmlOutputPath {
    let expandedPath = (htmlPath as NSString).expandingTildeInPath
    var htmlLines = [String]()
    htmlLines.append("<html>")
    htmlLines.append("<head>")
    htmlLines.append("<meta charset=\"utf-8\">")
    htmlLines.append("<meta name=\"generator\" content=\"lantmateriet-generator\">")
    htmlLines.append("<style>")
    htmlLines.append("body { font-family: sans-serif; }")
    htmlLines.append("table { border-collapse: collapse; border: 1px solid #ddd; }")
    htmlLines.append("tr { font-size: 12px; }")
    htmlLines.append("th, td { padding: 10px; border-bottom: 1px solid #ddd; }")
    htmlLines.append("th { background: #ddd; text-align: left; }")
    htmlLines.append("tr:nth-child(odd) { background-color: #f2f2f2; }")
    htmlLines.append("td:first-child { font-weight: bold; }")
    htmlLines.append("p { padding: 10px; font-size: 12px; }")
    htmlLines.append("</style>")
    htmlLines.append("</head>")
    htmlLines.append("<body>")
    htmlLines.append("<table>")
    htmlLines.append("<tr>")
    let headers = LantmaterietImageEntry.plainTextOutputColumnTitles(includingUrls: includeUrls)
    htmlLines.append(headers.compactMap({ "<th>\($0)</th>" }).joined())
    htmlLines.append("</tr>")
    for entry in entries {
        var columns = entry.plainTextOutputColumns(includingUrls: false).compactMap({ "<td>\($0)</td>" })
        if includeUrls {
            if let googleMapsUrl = entry.coordinate?.googleMapsUrl {
                columns.append("<td><a href=\"\(googleMapsUrl)\" target=\"_blank\">Google Maps</a></td>")
            } else {
                columns.append("<td></td>")
            }
            if let lantMaterietUrl = entry.swerefCoordinate?.lantmaterietUrl {
                columns.append("<td><a href=\"\(lantMaterietUrl)\" target=\"_blank\">Lantmäteriet</a></td>")
            } else {
                columns.append("<td></td>")
            }
        }
        htmlLines.append("<tr>\(columns.joined())</tr>")
    }
    htmlLines.append("</table>")
    htmlLines.append("<p>Locations marked with an asterisk (*) gave a low-accuracy lookup result and should be manually checked. Locations marked with (Missing) gave no lookup result at all.</p>")
    htmlLines.append("</head>")
    htmlLines.append("</html>")
    let data = htmlLines.joined(separator: "\n").data(using: .utf8)!
    do {
        try data.write(to: URL(fileURLWithPath: expandedPath))
    } catch {
        printUser("Writing to \(htmlPath) failed: \(error)")
    }
}

if textOutputPath == nil && htmlOutputPath == nil {
    // Print to stdout if no output methods are given.
    entries.forEach({ printResult($0.plainTextOutputColumns(includingUrls: includeUrls).joined(separator: "\t")) })
}

