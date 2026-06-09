import Combine
import SwiftUI

// MARK: - Panel State

@MainActor
final class PanelViewModel: ObservableObject {
    enum State {
        case loading
        case result(TranslationResult)
        case error(String)
    }

    @Published var state: State = .loading
}

// MARK: - Panel View

struct FloatingPanelView: View {
    @ObservedObject var viewModel: PanelViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch viewModel.state {
                case .loading:
                    loadingView
                case .result(let result):
                    resultContent(result)
                case .error(let message):
                    errorView(message)
                }
            }
            .padding(16)
            .frame(width: 420)
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView().scaleEffect(0.8).controlSize(.small)
            Text("翻译中...").foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private func resultContent(_ result: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(result.original)
                .font(.body).foregroundColor(.white).opacity(0.7)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(result.translation)
                .font(.title3).fontWeight(.medium).foregroundColor(.white)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(message).foregroundColor(.white).font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }
}
