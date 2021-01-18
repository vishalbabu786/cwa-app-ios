////
// 🦠 Corona-Warn-App
//
// Automated Test for the CWA Contact Diary
// This test creates many entires in the contact diary.
// The contactsPerCard variable controls how many entries get created per day.
// Preconditions:
// - App must be onboarded
// - the initial confirmation dialog of the contact diary ("Tagebuch führen") must be confirmed
// - language and locale must be DE
// The test starts on the Homescreen of the app.

import XCTest

class ENAUITests_07_ContactDiaryStressTest: XCTestCase {
	
	// MARK: - Attributes.
	
	var app: XCUIApplication!
	
	// MARK: - Setup.

	override func setUpWithError() throws {
		continueAfterFailure = false
		app = XCUIApplication()
		setupSnapshot(app)
		app.setDefaults()
		app.launchArguments += ["-AppleLanguages", "(de-DE)"]
		app.launchArguments += ["-AppleLocale", "\"de-DE\""]
	}
	
	// MARK: - Tests.
	
	func testContactDiaryView() throws {
			
		// navigate to diary
		app.launch()
		app.swipeUp()
		app.buttons["AppStrings.Home.diaryCardButton"].tap()
		
		// read the test data
		let myBundle = Bundle(for: type(of: self))
		var dataLines: [String] = []
		
		do {
	
			if let path = myBundle.path(forResource: "MOCK_DATA", ofType: "csv") {
				let fileData = try String(contentsOfFile: path, encoding: .utf8)
				dataLines = fileData.components(separatedBy: "\r\n")
				
			} else {
				XCTFail("MOCK_DATA.csv not found! Check file and path.")
			}
			
		} catch {
			XCTFail(error.localizedDescription)
		}
		
		// now run the contact diary test
		
		// generate the string list with the date button texts
		var dateCards: [String] = []
		let dateCartCount = 13
		let calendar = Calendar.current
		
		let dateFormatter = DateFormatter()
		dateFormatter.locale = Locale(identifier: "de-DE")
		dateFormatter.setLocalizedDateFormatFromTemplate("eeee, dd.MM.yy")
		
		for i in 0...dateCartCount {
			if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
				dateCards.append(dateFormatter.string(from: date))
			}
		}
		
		let contactsPerCard = 200
		let locationsPerCard = 10
		
		var addedContacts: Int = 0
		
		// process all cards and create contacts
		for card in dateCards {
			createContacts(cardName: card, contactData: dataLines, startNum: addedContacts, contactsToAdd: contactsPerCard, locationsToAdd: locationsPerCard)
			addedContacts += contactsPerCard
		}
	}
	
	// MARK: - Util Functions.
	
	// create locationsPerCard locations and contactsPerCard contacts
	func createContacts(cardName: String, contactData: [String], startNum: Int, contactsToAdd: Int, locationsToAdd: Int) {
		
		// navigate to the contact card
		let tablesQuery = app.tables
		tablesQuery.staticTexts[cardName].tap()
		
		// create a location using the first person data entry
		var personData: [String] = []
		
		app.buttons["Orte"].tap()
		
		for idx in 0...locationsToAdd {
			personData = contactData[idx].components(separatedBy: ",")
			createLocationEntry(locationName: personData[7])
		}
		
		app.buttons["Personen"].tap()

		for idx in startNum...startNum + contactsToAdd {
			personData = contactData[idx].components(separatedBy: ",")
			createContactEntry(contactName: personData[0] + " " + personData[1])
		}
		
		app.navigationBars.buttons.element(boundBy: 0).tap()
	}
	
	// create single location entry
	func createLocationEntry(locationName: String) {
		let tablesQuery = app.tables
		tablesQuery.staticTexts["Ort hinzufügen"].tap()
		
		let navnTextField = app.textFields["Ort"]
		navnTextField.typeText(locationName)
		
		app.staticTexts["Speichern"].tap()
	}
	
	// create single contact entry
	func createContactEntry(contactName: String) {
		let tablesQuery = app.tables
		tablesQuery.staticTexts["Person hinzufügen"].tap()
		
		let navnTextField = app.textFields["Person"]
		navnTextField.typeText(contactName)
		
		app.staticTexts["Speichern"].tap()
	}
}
