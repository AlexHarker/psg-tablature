\version "2.24.1"

\include "psg-tablature.ly"
\include "psg-copendent.ly"

\header
{
  title = "Pedal Steel Guitar"
}

myNotes = \transpose c c'
{
  \set TabStaff.restrainOpenStrings = ##t
  <e\6 a\5 cis'\4>4 \psgOn A \psgOn LKL <e\6 a\5 cis'\4>4 \psgOff LKL <e\6 a\5 cis'\4>4 \psgOff A \psgOn LKL <e\6 a\5 cis'\4>2 \psgOff LKL e'4\4
  <e\6 a\5 cis'\4>4 \psgOn A \psgOn LKL <e\6 a\5 c'\4>4 \psgOff LKL <e\6 g\5 cis'\4>4 \psgOff A \psgOn LKL <e\6 g\5 c'\4>2 \psgOff LKL e'4\4
  d,\10 \psgOn A d,\10 \psgOff A d,\10 \psgFractional A 1 2 c, c, \psgOff A cis, cis, \psgOn A b,, \psgOff A
  \bar "|."
}

\paper
{
  system-system-spacing = #'((basic-distance . 20) (padding . 3))
}

\score
{
  \layout
  {
    indent = 40

    \context
    {
      \Score
      \override StaffGrouper.staff-staff-spacing.padding = 0
      \override StaffGrouper.staff-staff-spacing.basic-distance = 20
    }

    \context
    {
      \Staff
      \omit StringNumber
    }

    \context
    {
      \TabStaff
      \name PedalSteelTab
      \alias TabStaff
      \consists #psg-tab-engraver
      
      %% Overrides for tab in a space
      
      \override TabNoteHead.extra-offset = #'(0 . -0.5)
      \override TabNoteHead.font-size = #-3
     % \override TabNoteHead.whiteout = ##f
      
      copedent = \copedentE
      psgTabInSpace = ##t
      
      #(psg-tab-clef  #{\copedentE#} #t)
    }
    \inherit-acceptability PedalSteelTab TabStaff
    \inherit-acceptability TabStaff PedalSteelTab
  }

  \new StaffGroup <<
    \new Staff
    {
      \clef "G"
      \key a \major
      \time 3/4
      \myNotes
    }
    \new PedalSteelTab
    {
      \myNotes
    }
  >>
}