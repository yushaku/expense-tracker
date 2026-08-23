import MijickCalendarView
import SwiftUI

/// A date control shaped like the text fields beside it: a themed row showing
/// the chosen date, opening a month calendar in a popover.
///
/// A bare `DatePicker` renders as a stepper field on Mac and a grey inline row
/// on iPhone, neither of which matches the surrounding cards. The popover keeps
/// the full calendar available without spending the ~300pt an inline calendar
/// would take in every form, and draws it with MijickCalendarView, which is
/// plain SwiftUI on both platforms.
struct DateField: View {
    @Binding var selection: Date

    let accessibilityIdentifier: String

    @State private var isPickingDate = false

    private static let displayFormat: Date.FormatStyle = {
        var style = Date.FormatStyle().day().month(.abbreviated).year()
        style.calendar = TransactionPeriod.calendar
        style.timeZone = TransactionPeriod.calendar.timeZone
        style.locale = Locale(identifier: "en_US")
        return style
    }()

    private var formattedDate: String {
        Self.displayFormat.format(selection)
    }

    var body: some View {
        Button {
            isPickingDate = true
        } label: {
            HStack(spacing: 12) {
                Text(formattedDate)
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(MonMonTheme.textPrimary)

                Spacer(minLength: 8)

                Image(systemName: "calendar")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(MonMonTheme.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                MonMonTheme.field,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("Date, \(formattedDate)")
        .accessibilityHint("Opens a calendar.")
        .popover(isPresented: $isPickingDate) {
            calendar
        }
    }

    private var calendar: some View {
        MCalendarView(selectedDate: pickedDate, selectedRange: nil) {
            $0
                .startMonth(CalendarTheme.startMonth())
                .endMonth(CalendarTheme.endMonth())
                .dayView(ThemedDayView.init)
                .monthLabel(ThemedMonthLabel.init)
                .weekdaysView(ThemedWeekdaysView.init)
                .monthLabelToDaysDistance(14)
                .daysVerticalSpacing(4)
                .monthsViewBackground(MonMonTheme.surface)
                .scrollTo(date: selection)
        }
        .padding(16)
        .frame(minWidth: 320, minHeight: 380)
        .background(MonMonTheme.surface)
        .tint(MonMonTheme.accent)
        .accessibilityIdentifier("\(accessibilityIdentifier)-calendar")
        // Without this an iPhone would present a sheet instead of a popover,
        // which reads as a heavier decision than picking a day.
        .presentationCompactAdaptation(.popover)
    }

    /// The calendar hands back an optional date and expects to keep offering
    /// one; this field always has a date, so a cleared selection keeps the
    /// current one rather than leaving the form without a date at all.
    private var pickedDate: Binding<Date?> {
        Binding(
            get: { selection },
            set: { newValue in
                guard let newValue else {
                    return
                }

                selection = newValue
                isPickingDate = false
            }
        )
    }
}

#if DEBUG
    private struct DateFieldPreview: View {
        @State var selection = Date(timeIntervalSince1970: 1_787_000_000)

        var body: some View {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Date")
                        .font(.subheadline.weight(.medium))

                    DateField(selection: $selection, accessibilityIdentifier: "preview-date")
                }
                .padding(20)
                .frame(maxWidth: 400)
            }
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    #Preview("Date field") {
        DateFieldPreview()
    }
#endif
