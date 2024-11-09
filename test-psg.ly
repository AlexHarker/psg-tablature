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

stringA = \markup{\line{\concat{F\raise #0.5 \fontsize #-4 {\sharp}}}}
stringB = \markup{\line{\concat{D\raise #0.5 \fontsize #-4 {\sharp}}}}
stringC = \markup{\line{\concat{G\raise #0.5 \fontsize #-4 {\sharp}}}}
stringD = \markup{E}
stringE = \markup{B}
stringF = \markup{\line{\concat{G\raise #0.5 \fontsize #-4 {\sharp}}}}
stringG = \markup{\line{\concat{F\raise #0.5 \fontsize #-4 {\sharp}}}}
stringH = \markup{E}
stringI = \markup{D}
stringJ = \markup{B}
                 
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

      copedent = \copedentE

      \override Clef.stencil = #(lambda (grob)
        (grob-interpret-markup grob
          #{
            \markup
            \override #'(baseline-skip . 1.5)
            %% \whiteout
            \concat
            {
              \hspace #-.8
              \with-dimensions #'(0 . 0) #'(0 . 0)
              \lower #7.5 \draw-line #'(0 . 15)
              \hspace #0.5
              \raise #6.2 \center-column \sans \fontsize #-3 { 1 2 3 4 5 6 7 8 9 10 }
              \hspace #0.25
              \with-dimensions #'(0 . 0) #'(0 . 0)
              \hspace #0.25
              \raise #6.2 \center-column \sans \fontsize #-3 { \stringA \stringB \stringC \stringD \stringE \stringF \stringG \stringH \stringI \stringJ }
              \hspace #0.5
              \with-dimensions #'(0 . 0) #'(0 . 0)
              \lower #7.5 \draw-line #'(0 . 15)
            }
          #}))
    }
    \inherit-acceptability PedalSteelTab TabStaff
    \inherit-acceptability TabStaff PedalSteelTab

    \context
    {
      \TabVoice
      \override TabNoteHead.extra-offset = #'(0 . -0.5)
      \override TabNoteHead.font-size = #-3
      \override TabNoteHead.whiteout = ##t
    }
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