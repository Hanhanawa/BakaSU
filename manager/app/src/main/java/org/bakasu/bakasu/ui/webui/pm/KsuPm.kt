package org.bakasu.bakasu.ui.webui.pm

import android.webkit.JavascriptInterface
import org.bakasu.bakasu.data.webui.WebUiBackend

/** Package-manager bridge for the device that owns the module. */
class KsuPm(private val backend: WebUiBackend) {
    @JavascriptInterface
    fun version(): Int = 1

    @JavascriptInterface
    fun listPackages(type: String): String = backend.listPackages(type)

    @JavascriptInterface
    fun getPackagesInfo(packageNamesJson: String): String = backend.getPackagesInfo(packageNamesJson)
}
