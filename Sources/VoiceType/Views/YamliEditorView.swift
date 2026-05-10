import SwiftUI
import WebKit

struct YamliEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var isReady: Bool
    @Binding var didFail: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isReady: $isReady, didFail: $didFail)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "voiceType")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.loadHTMLString(Self.html, baseURL: URL(string: "https://www.yamli.com/"))
        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.setTextIfNeeded(text)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "voiceType")
    }
}

extension YamliEditorView {
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        @Binding private var text: String
        @Binding private var isReady: Bool
        @Binding private var didFail: Bool

        weak var webView: WKWebView?
        private var webText = ""

        init(text: Binding<String>, isReady: Binding<Bool>, didFail: Binding<Bool>) {
            _text = text
            _isReady = isReady
            _didFail = didFail
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }

            let value = body["value"] as? String ?? ""

            DispatchQueue.main.async {
                switch type {
                case "ready":
                    self.isReady = true
                    self.didFail = false
                    self.updateText(value)
                case "change":
                    self.updateText(value)
                case "failed":
                    self.isReady = false
                    self.didFail = true
                    self.updateText(value)
                default:
                    break
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isReady = false
                self.didFail = true
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.isReady = false
                self.didFail = true
            }
        }

        func setTextIfNeeded(_ nextText: String) {
            guard nextText != webText else {
                return
            }

            webText = nextText
            guard let data = try? JSONSerialization.data(withJSONObject: [nextText]),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }

            webView?.evaluateJavaScript("window.voiceTypeSetValue(\(json)[0]);")
        }

        private func updateText(_ value: String) {
            webText = value
            if text != value {
                text = value
            }
        }
    }

    private static let html = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        html, body {
          margin: 0;
          padding: 0;
          width: 100%;
          height: 100%;
          overflow: hidden;
          background: transparent;
          color: #f2f2f2;
          font: 18px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }

        textarea {
          box-sizing: border-box;
          width: 100%;
          height: 100%;
          resize: none;
          border: 1px solid rgba(255, 255, 255, 0.16);
          border-radius: 8px;
          padding: 10px;
          outline: none;
          background: #1f1f1f;
          color: #f2f2f2;
          font: 22px -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          line-height: 1.35;
        }
      </style>
    </head>
    <body>
      <textarea id="yamli-editor" spellcheck="false" autocomplete="off" autocorrect="off" placeholder="Type Arabizi here..."></textarea>
      <script src="https://api.yamli.com/js/yamli_api.js"></script>
      <script>
        const editor = document.getElementById("yamli-editor");
        let yamliReady = false;

        function post(type) {
          try {
            window.webkit.messageHandlers.voiceType.postMessage({
              type: type,
              value: editor.value
            });
          } catch (_) {}
        }

        function notifyChange() {
          post("change");
        }

        window.voiceTypeSetValue = function(value) {
          if (editor.value !== value) {
            editor.value = value || "";
            notifyChange();
          }
        };

        editor.addEventListener("input", notifyChange);
        editor.addEventListener("keyup", notifyChange);
        editor.addEventListener("change", notifyChange);

        function initializeYamli() {
          try {
            if (typeof Yamli === "object" && Yamli.init()) {
              Yamli.yamlify("yamli-editor", {
                uiLanguage: "en",
                startMode: "on",
                generateOnChangeEvent: true,
                settingsPlacement: "bottomLeft"
              });
              yamliReady = true;
              post("ready");
              return;
            }
          } catch (_) {}

          post("failed");
        }

        window.addEventListener("load", function() {
          setTimeout(initializeYamli, 100);
          setInterval(notifyChange, 300);
          setTimeout(function() {
            if (!yamliReady) {
              post("failed");
            }
          }, 5000);
        });
      </script>
    </body>
    </html>
    """
}
