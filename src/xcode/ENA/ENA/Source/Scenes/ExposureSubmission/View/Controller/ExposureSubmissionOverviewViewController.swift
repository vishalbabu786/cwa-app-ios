// Corona-Warn-App
//
// SAP SE and all other contributors
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import AVFoundation
import Foundation
import UIKit

class ExposureSubmissionOverviewViewController: DynamicTableViewController, SpinnerInjectable {

	// MARK: - Attributes.

	var spinner: UIActivityIndicatorView?
	private(set) weak var coordinator: ExposureSubmissionCoordinating?
	private(set) weak var service: ExposureSubmissionService?
	private let viewModel: ExposureSubmissionOverviewViewModel

	// MARK: - Initializers.

	required init?(coder: NSCoder, coordinator: ExposureSubmissionCoordinating, exposureSubmissionService: ExposureSubmissionService) {
		self.service = exposureSubmissionService
		self.coordinator = coordinator
		self.viewModel = ExposureSubmissionOverviewViewModel()
		super.init(coder: coder)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - View lifecycle methods.

	override func viewDidLoad() {
		super.viewDidLoad()
		dynamicTableViewModel = dynamicTableData()
		setupView()
	}

	private func setupView() {
		tableView.register(
			UINib(
				nibName: String(describing: ExposureSubmissionTestResultHeaderView.self),
				bundle: nil
			),
			forHeaderFooterViewReuseIdentifier: "test"
		)
		tableView.register(UINib(nibName: String(describing: ExposureSubmissionImageCardCell.self), bundle: nil), forCellReuseIdentifier: CustomCellReuseIdentifiers.imageCard.rawValue)
		title = AppStrings.ExposureSubmissionDispatch.title
	}

	// MARK: - Helpers.

	/// Shows the data privacy disclaimer and only lets the
	/// user scan a QR code after accepting.
	func showDisclaimer() {
		let alert = UIAlertController(
			title: AppStrings.ExposureSubmission.dataPrivacyTitle,
			message: AppStrings.ExposureSubmission.dataPrivacyDisclaimer,
			preferredStyle: .alert
		)
		let acceptAction = UIAlertAction(
			title: AppStrings.ExposureSubmission.dataPrivacyAcceptTitle,
			style: .default,
			handler: { _ in
				self.service?.acceptPairing()
				self.coordinator?.showQRScreen(qrScannerDelegate: self)
			}
		)
		alert.addAction(acceptAction)

		alert.addAction(.init(title: AppStrings.ExposureSubmission.dataPrivacyDontAcceptTitle,
							  style: .cancel,
							  handler: { _ in
								alert.dismiss(animated: true, completion: nil) }
			))
		alert.preferredAction = acceptAction
		present(alert, animated: true, completion: nil)
	}
}

// MARK: - ExposureSubmissionQRScannerDelegate methods.

extension ExposureSubmissionOverviewViewController: ExposureSubmissionQRScannerDelegate {
	func qrScanner(_ viewController: QRScannerViewController, error: QRScannerError) {
		switch error {
		case .cameraPermissionDenied:

			// The error handler could have been invoked on a non-main thread which causes
			// issues (crash) when updating the UI.
			DispatchQueue.main.async {
				let alert = self.setupErrorAlert(
					message: error.localizedDescription,
					completion: {
						self.dismissQRCodeScannerView(viewController, completion: nil)
				 })
				viewController.present(alert, animated: true, completion: nil)
			}
		default:
			logError(message: "QRScannerError.other occurred.", level: .error)
		}
	}

	func qrScanner(_ vc: QRScannerViewController, didScan code: String) {
		guard let guid = viewModel.sanitizeAndExtractGuid(code) else {
			vc.delegate = nil

			let alert = self.setupErrorAlert(
				title: AppStrings.ExposureSubmissionQRScanner.alertCodeNotFoundTitle,
				message: AppStrings.ExposureSubmissionQRScanner.alertCodeNotFoundText,
				okTitle: AppStrings.Common.alertActionCancel,
				secondaryActionTitle: AppStrings.Common.alertActionRetry,
				completion: {
					self.dismissQRCodeScannerView(vc, completion: nil)
				},
				secondaryActionCompletion: { vc.delegate = self }
			)
			vc.present(alert, animated: true, completion: nil)
			return
		}

		// Found QR Code, deactivate scanning.
		dismissQRCodeScannerView(vc, completion: {
			self.getTestResults(forKey: .guid(guid))
		})
	}

	private func getTestResults(forKey key: DeviceRegistrationKey) {
		self.startSpinner()
		service?.getTestResult(forKey: key, useStoredRegistration: false, completion: { result in
			self.stopSpinner()
			switch result {
			case let .failure(error):
				// Note: In the case the QR Code was already used, retrying will result
				// in an endless loop.
				if case .qRAlreadyUsed = error {
					let alert = self.setupErrorAlert(
						title: AppStrings.ExposureSubmissionError.qrAlreadyUsedTitle,
						message: error.localizedDescription
					)
					self.present(alert, animated: true, completion: nil)
					return
				}
				
				logError(message: "An error occurred during result fetching: \(error)", level: .error)

				let alert = self.setupErrorAlert(
					message: error.localizedDescription,
					secondaryActionTitle: AppStrings.Common.alertActionRetry,
					secondaryActionCompletion: {
						self.getTestResults(forKey: key)
					}
				)
				self.present(alert, animated: true, completion: nil)
			case let .success(testResult):
				self.coordinator?.showTestResultScreen(with: testResult)
			}
		})
	}

	private func dismissQRCodeScannerView(_ vc: QRScannerViewController, completion: (() -> Void)?) {
		vc.delegate = nil
		vc.dismiss(animated: true, completion: completion)
	}
}

// MARK: Data extension for DynamicTableView.

private extension DynamicCell {
	static func imageCard(
		title: String,
		description: String? = nil,
		attributedDescription: NSAttributedString? = nil,
		image: UIImage?,
		action: DynamicAction,
		accessibilityIdentifier: String? = nil) -> Self {
		.identifier(ExposureSubmissionOverviewViewController.CustomCellReuseIdentifiers.imageCard, action: action) { _, cell, _ in
			guard let cell = cell as? ExposureSubmissionImageCardCell else { return }
			cell.configure(
				title: title,
				description: description ?? "",
				attributedDescription: attributedDescription,
				image: image,
				accessibilityIdentifier: accessibilityIdentifier)
		}
	}
}

private extension ExposureSubmissionOverviewViewController {
	func dynamicTableData() -> DynamicTableViewModel {
		var data = DynamicTableViewModel([])

		let header = DynamicHeader.blank

		data.add(
			.section(
				header: header,
				separators: false,
				cells: [
					.body(
						text: AppStrings.ExposureSubmissionDispatch.description,
						accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionDispatch.description)
				]
			)
		)

		data.add(DynamicSection.section(cells: [
			.imageCard(
				title: AppStrings.ExposureSubmissionDispatch.qrCodeButtonTitle,
				description: AppStrings.ExposureSubmissionDispatch.qrCodeButtonDescription,
				image: UIImage(named: "Illu_Submission_QRCode"),
				action: .execute(block: { [weak self] _ in self?.showDisclaimer() }),
				accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionDispatch.qrCodeButtonDescription
			),
			.imageCard(
				title: AppStrings.ExposureSubmissionDispatch.tanButtonTitle,
				description: AppStrings.ExposureSubmissionDispatch.tanButtonDescription,
				image: UIImage(named: "Illu_Submission_TAN"),
				action: .execute(block: { [weak self] _ in self?.coordinator?.showTanScreen() }),
				accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionDispatch.tanButtonDescription
			),
			.imageCard(
				title: AppStrings.ExposureSubmissionDispatch.hotlineButtonTitle,
				attributedDescription: applyFont(style: .headline, to: AppStrings.ExposureSubmissionDispatch.hotlineButtonDescription, with: AppStrings.ExposureSubmissionDispatch.positiveWord),
				image: UIImage(named: "Illu_Submission_Anruf"),
				action: .execute(block: { [weak self] _ in self?.coordinator?.showHotlineScreen() }),
				accessibilityIdentifier: AccessibilityIdentifiers.ExposureSubmissionDispatch.hotlineButtonDescription
			)
		]))

		return data
	}

	private func applyFont(style: ENAFont, to text: String, with content: String) -> NSAttributedString {
		return NSMutableAttributedString.generateAttributedString(normalText: text, attributedText: [
			NSAttributedString(string: content, attributes: [
				NSAttributedString.Key.font: UIFont.enaFont(for: style)
			])
		])
	}
}

// MARK: - Cell reuse identifiers.

extension ExposureSubmissionOverviewViewController {
	enum CustomCellReuseIdentifiers: String, TableViewCellReuseIdentifiers {
		case imageCard = "imageCardCell"
	}
}

// MARK: - ExposureSubmissionOverviewViewModel.

struct ExposureSubmissionOverviewViewModel {

	/// Sanitizes the input string and extracts a guid.
	/// - the input needs to start with https://localhost/?
	/// - the input must not ne longer than 150 chars and cannot be empty
	/// - the guid contains only the following characters: a-f, A-F, 0-9,-
	/// - the guid is a well formatted string (6-8-4-4-4-12) with length 43
	///   (6 chars encode a random number, 32 chars for the uuid, 5 chars are separators)
	func sanitizeAndExtractGuid(_ input: String) -> String? {
		guard
			!input.isEmpty,
			input.count <= 150,
			let regex = try? NSRegularExpression(
				pattern: "^https:\\/\\/localhost\\/\\?(?<GUID>[0-9A-Fa-f]{6}-[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})$"
			),
			let match = regex.firstMatch(in: input, options: [], range: NSRange(location: 0, length: input.utf8.count))
		else { return nil }

		guard let range = Range(match.range(withName: "GUID"), in: input) else { return nil }
		let candidate = String(input[range])
		guard !candidate.isEmpty, candidate.count == 43 else { return nil }
		return candidate
	}
}
