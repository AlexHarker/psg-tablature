\version "2.24.1"

\include "psg-tablature.ly"
\include "psg-copedent.ly"

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
      \PedalSteelTab 
      copedent = \copedentE
      psgTabInSpace = ##t
    }
  }
  
  \new StaffGroup <<
    \new PedalSteelStaff
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