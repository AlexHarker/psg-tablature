\version "2.24.1"

%% PSG event definitions

#(define (define-event! type properties)
  (set-object-property! type
    'music-description
    (cdr (assq 'description properties)))
  (set! properties (assoc-set! properties 'name type))
  (set! properties (assq-remove! properties 'description))
  (hashq-set! music-name-to-property-table type properties)
  (set! music-descriptions
    (sort (cons (cons type properties)
      music-descriptions)
      alist<?)))

#(define-event-class 'psg-pedal-or-lever-event 'span-event)

#(define-event!
  'PsgPedalOrLeverEvent
  '((description . "Engage or release PSG pedal or knee level.")
    (types . (post-event event pedal-event psg-pedal-or-lever-event))))

%% ID helpers

#(define (psg-id-to-string x)
  (if (string? x)
    (begin x)
    (if (symbol? x)
      (symbol->string x)
      (number->string x))))

#(define (psg-id-type? x)
  (if (string? x)
    (begin #t)
    (if (symbol? x)
      (begin #t)
      (number? x))))
     
%% Event creation

make-psg-pedal-event =
#(define-music-function
  (id span-dir amount)
  (psg-id-type? number? rational?)
  (if (> amount 2)
    (begin
      (ly:warning "Pedal or lever event with amount greater than extended (2) - processing as extended")
      (set! amount 2)))
  (if (<= amount 0)
    (begin
      (ly:warning "Pedal or lever event with zero or negative amount - setting to 1")
      (set! amount 1)))
  (make-music 'PsgPedalOrLeverEvent 'span-direction span-dir 'id (psg-id-to-string id) 'amount amount))

psgFractional =
#(define-music-function
  (id num denom)
  (psg-id-type? integer? integer?)
  (make-psg-pedal-event id START (/ num denom)))

psgExt =
#(define-music-function
  (id)
  (psg-id-type?)
  (make-psg-pedal-event id START 2))

psgOn =
#(define-music-function
  (id)
  (psg-id-type?)
  (make-psg-pedal-event id START 1))

psgOff =
#(define-music-function
  (id)
  (psg-id-type?)
  (make-psg-pedal-event id STOP 1))

%% Copedent checks & predicate - here we define correct or bad input for defining copedents

#(define (psg-check-strings strings)
  (if (null? strings)
    (begin #t)
    (if (and (list? strings) (ly:pitch? (car strings)))
      (psg-check-strings (cdr strings))
      (ly:error ("Strings must be expressed as a list of pitches - use \\stringTuning to create!")))))

#(define (psg-check-alterations alterations)
  (if (null? alterations)
    (begin #t)
    (if (and (list? alterations) (number? (car alterations)))
      (psg-check-alterations (cdr alterations))
      (ly:error ("String alterations must be expressed a list of numbers in semitones!")))))

#(define (psg-check-pedals-and-levers strings pedal-and-levers)
  (if (null? pedal-and-levers)
    (begin #t)
    (let ((current-alterations (cadar pedal-and-levers))
      (extended-alterations (caddar pedal-and-levers)))
      (if (and (= (length current-alterations) (length strings)) (or (null? extended-alterations)(= (length extended-alterations) (length strings))))
        (and (psg-check-alterations current-alterations) (psg-check-alterations extended-alterations) (psg-check-pedals-and-levers strings (cdr pedal-and-levers)))
        (ly:error ("Number of string alterations in pedal or lever doesn't match the number of strings!"))))))

#(define (psg-copedent? copedent)
  (if (and (not (null? copedent)) (list? copedent))
    (let ((strings (car copedent))
      (pedals-and-levers (cdr copedent)))
      (and (psg-check-strings strings) (psg-check-pedals-and-levers strings pedals-and-levers)))
    (begin #f)))

%% Context properties

#(set-object-property! 'psgCopedent 'translation-type? psg-copedent?)
#(set-object-property! 'psgTabInSpace 'translation-type? boolean?)
#(set-object-property! 'psgClefStyle 'translation-type? symbol?)

%% Copedent definition functions

psg-define-pedal-or-lever-ext =
#(define-scheme-function
  (id alterations extended-alterations)
  (psg-id-type? list? list?)
  (list (psg-id-to-string id) (reverse alterations) (reverse extended-alterations)))

psg-define-pedal-or-lever =
#(define-scheme-function
  (id alterations)
  (psg-id-type? list?)
  (psg-define-pedal-or-lever-ext id alterations '()))

psg-define-copedent =
#(define-scheme-function
  (strings pedal-and-levers)
  (list? list?)
  (define copedent (append (list strings) pedal-and-levers))
  (if (psg-copedent? copedent)
    (begin copedent)
    (begin (ly:error ("Copedent is not correctly defined!")'(())))))
    
%% Utilities for accessing parts of a copedent

#(define (psg-copedent-strings copedent)
  (car copedent))
  
#(define (psg-copedent-pedals-and-levers copedent)
  (cdr copedent))

#(define (psg-copedent-num-strings copedent)
  (length (psg-copedent-strings copedent)))

#(define (psg-copedent-num-pedals-and-levers copedent)
  (length (psg-copedent-pedals-and-levers copedent)))

#(define (psg-copedent-id-list copedent)
  (map car (psg-copedent-pedals-and-levers copedent)))

#(define (psg-alterations-for-id copedent id)
  (define id-list (psg-copedent-id-list copedent))
  (define id-sublist (member id id-list))
  (if id-sublist
    (let ((pedals-and-levers (psg-copedent-pedals-and-levers copedent)))
      (cdr (list-ref pedals-and-levers (- (length pedals-and-levers) (length id-sublist)))))
    (begin #f)))

%% Evaluation of copedents - here we define functions for deftermining the active tuning given a copedent and set of active pedals or levers

#(define (transpose-string pitch alter)
  (begin
    (ly:make-pitch
      (ly:pitch-octave pitch)
      (ly:pitch-notename pitch)
      (+ (ly:pitch-alteration pitch) (/ alter 2)))))

#(define (sum-alterations prev add)
  (if (and (not (= add 0)) (not (= prev 0)))
    (ly:error "Impossible pedal/lever combination"))
  (+ prev add))

#(define (calculate-alterations normal extended amount)
  (if (<= amount 1)
      (map (lambda (a) (* a amount)) normal)
      (map (lambda (a b) (+ (* (- amount 1) b) (* (- 2 amount) a))) normal extended)))

#(define (psg-evaluation-loop adjust copedent active)
  (if (null? active)
    (begin adjust)
    (let ((alterations (psg-alterations-for-id copedent (caar active)))
      (amount (cadar active)))
      (if alterations
        (begin
          (set! adjust (psg-evaluation-loop adjust copedent (cdr active)))
          (map sum-alterations adjust (calculate-alterations (car alterations) (cadr alterations) amount)))
        (begin adjust)))))

#(define (psg-evaluate-copedent copedent active offset)
  (define strings (psg-copedent-strings copedent))
  (define adjust (map (lambda (x) (begin 0)) strings))
  
  (if (not (null? (psg-copedent-pedals-and-levers copedent)))
    (begin
      (set! adjust (psg-evaluation-loop adjust copedent active))
      (set! strings (map transpose-string strings adjust))))
  
  ; check whether to add an additional string for display style
  
  (if offset
    (append strings (list #{c''''''''#}))
    strings))

%% Clef stencil

#(define (psg-tab-clef-stencil copedent in-space style)
  (define (height-calculate in-space)
    (+ (* (- (psg-copedent-num-strings copedent) 1) 0.75) in-space))
  (let
   ((height (if in-space (height-calculate -0.55) (height-calculate -0.59)))
    (line-height (if in-space (* (psg-copedent-num-strings copedent) 1.5) (* (- (psg-copedent-num-strings copedent) 1) 1.5))))
   (lambda (grob)
    (grob-interpret-markup grob
      #{
       \markup
       \override #'(baseline-skip . 1.5)
       \concat
       {
        \hspace #-0.3
        #(case style
          ((0)
          #{
            \markup 
            \concat
            { 
             \raise #height \center-column \sans \fontsize #-3 #(psg-string-numbers-makuplist copedent)
             \hspace #0.4
             \raise #height \center-column \sans \fontsize #-3 #(psg-string-names-markuplist copedent)
            }
          #})
          ((1)
          #{
            \markup \raise #height \center-column \sans \fontsize #-3 #(psg-string-numbers-makuplist copedent)
          #})
          ((2)
          #{
            \markup \raise #height \center-column \sans \fontsize #-3 #(psg-string-names-markuplist copedent)
          #}))
        \hspace #0.5
        \lower #(/ line-height 2) \draw-line #(cons 0 line-height)
       }
      #}))))

%% Engraver

#(define (psg-valid-pedal-or-lever copedent id amount)
  (define alterations (psg-alterations-for-id copedent id))
  
  (if alterations
    (if (and (> amount 1) (null? (cadr alterations)))
      (begin 
        (ly:warning "Pedal or lever ~a does not have extension - ignoring!" id)
        #f)
      #t)
    (begin
      (ly:warning "No pedal or lever with id ~a in copedent - ignoring!" id)
      #f)))

#(define (psg-id-find active id)
  (if (null? active)
    (begin #f)
    (if (equal? (caar active) id)
      (begin #t)
      (psg-id-find (cdr active) id))))

#(define (psg-remove-id active id)
  (filter (lambda (x) (not (equal? (car x) id))) active))

#(define (psg-add-id active id amount)
  (append active (list (list id amount))))

#(define (psg-tab-engraver context)
  (let
    ((copedent (ly:context-property context 'psgCopedent))
     (in-space (ly:context-property context 'psgTabInSpace))
     (clef-style (if (equal? (ly:context-property context 'psgClefStyle) 'both) 0 (if (equal? (ly:context-property context 'psgClefStyle) 'numbers) 1 2)))
     (active '())
     (clefs '())
     (note-heads '()))
    (make-engraver
      ((initialize engraver)
        (if (not (psg-copedent? copedent))
          (ly:error "Copedent is not defined for PSGTabStaff"))
        (ly:context-set-property! context 'stringTunings (psg-evaluate-copedent copedent active in-space)))
      (listeners
        ((psg-pedal-or-lever-event engraver event)
          (define dir (ly:event-property event 'span-direction))
          (define id (ly:event-property event 'id))
          (define amount (ly:event-property event 'amount))
          (if (psg-valid-pedal-or-lever copedent id amount)
            (begin
              (if (eq? dir START)
                (if (not (psg-id-find active id))
                  (set! active (psg-add-id active id amount))
                  (if (member (list id amount) active)
                    (ly:warning "Pedal or lever ~a re-engaged at the same amount without releasing/changing it" id)
                    (set! active (psg-add-id (psg-remove-id active id) id amount))))
                (if (psg-id-find active id)
                  (set! active (psg-remove-id active id))
                  (ly:warning "Pedal or lever ~a released without engaging it" id)))
              (ly:context-set-property! context 'stringTunings (psg-evaluate-copedent copedent active in-space))))))
      (acknowledgers
        ((clef-interface engraver grob source-engraver)
          (set! clefs (cons grob clefs)))
        ((note-head-interface engraver grob source-engraver)
          (set! note-heads (cons grob note-heads))))
      ((process-acknowledged engraver)
        (for-each
          (lambda (clef)
            (ly:grob-set-property! clef 'stencil (psg-tab-clef-stencil copedent in-space clef-style)))
          clefs)
        (set! clefs '())
        (if in-space
          (for-each
            (lambda (note-head)
              (ly:grob-set-property! note-head 'extra-offset '(0 . -0.5))
              (ly:grob-set-property! note-head 'font-size -3)
              (ly:grob-set-property! note-head 'whiteout #f))
            note-heads))
        (set! note-heads '())))))
  
%% Markup for copedents

#(define (psg-markuplist-loop idx to proc)
  (if (>= idx to)
    (list (proc idx))
    (append (list (proc idx)) (psg-markuplist-loop (+ idx 1) to proc))))

#(define (psg-pitch-to-markup pitch whiteout)
  (let ((alteration (ly:pitch-alteration pitch))
        (letter (string (integer->char (+ 65 (modulo (- (ly:pitch-notename pitch) 5) 7)))))
        (item (if whiteout #:whiteout #:simple)))
    (if (= alteration 0)
      (markup (begin item letter))
      (markup (begin item (make-concat-markup (list (markup #:simple letter) (markup (#:raise 0.6 (#:fontsize -4 (make-accidental-markup alteration)))))))))))

#(define (psg-string-numbers-makuplist copedent)
  (psg-markuplist-loop 1 (psg-copedent-num-strings copedent) (lambda (x) (markup (#:whiteout (number->string x))))))

#(define (psg-string-names-markuplist copedent)
  (define strings (psg-copedent-strings copedent))
  (psg-markuplist-loop 0 (- (psg-copedent-num-strings copedent) 1) (lambda (x) (markup (#:whiteout (psg-pitch-to-markup (list-ref strings x) #t))))))

#(define (psg-alteration-markup copedent id stringnum names)
  (define (get-pitch amount)
    (psg-pitch-to-markup (list-ref (psg-evaluate-copedent copedent (list (list id amount)) #f) stringnum) #f))
  (define alterations (psg-alterations-for-id copedent id))
  (define alt (car alterations))
  (define ext (cadr alterations))
  (define basic (list-ref alt stringnum))
  (define (numtostring x)
    (if (> x 0) (string-join (list "+" (number->string x)) "") (number->string x)))
  (if (or (null? ext) (= basic (list-ref ext stringnum)))
     (if (= basic 0)
        (markup #:simple "")
        (if names 
          (get-pitch 1) 
          (markup #:simple (numtostring basic))))
     (if names 
        (make-concat-markup (list (get-pitch 1) (markup #:simple "/") (get-pitch 2)))
        (make-concat-markup (list (markup #:simple (numtostring basic)) (markup #:simple "/") (markup #:simple (numtostring (list-ref ext stringnum))))))))

%% Copedent diagram markup

#(define-markup-command (psg-copedent-diagram-box layout props size text color)
  (number? markup? color?)
  (let ((width size) (height (/ size 2.5)) (thickness (/ size 80)))
    (interpret-markup layout props
      #{
        \markup
        {
          \overlay
          {
            \override #'(line-cap-style . butt)
            \override #'(line-join-style . miter)
            \with-color #color
            \override #'(filled . #t) \path #thickness
              #`((moveto 0 0)
                (lineto ,width 0)
                (lineto ,width ,height)
                (lineto 0 ,height)
                (closepath))
            \translate #`(,(/ width 2) . ,(/ height 2)) \center-align \vcenter \sans \fontsize #-4 { #text }
          }
        }
      #})))

#(define (psg-string-loop copedent size id labelproc colorproc)
  (markup (#:override `(baseline-skip . ,(/ size 2.2)) (make-column-markup
    (psg-markuplist-loop 0 (psg-copedent-num-strings copedent)
      (lambda (x)
        (begin
          #{
            \markup \psg-copedent-diagram-box #size #(if (> x 0) (labelproc (- x 1)) (markup #:bold id)) #(colorproc x)
          #})))))))

#(define (psg-pedal-lever-loop copedent size headingcolor color1 color2 names)
  (define id-list (psg-copedent-id-list copedent))
  (define strings (psg-copedent-strings copedent))
  (psg-markuplist-loop 0 (psg-copedent-num-pedals-and-levers copedent)
    (lambda (x)
      (define id (if (> x 0) (list-ref id-list (- x 1)) ""))
      (let
        ((listproc (if (> x 0) (lambda (y) (psg-alteration-markup copedent id y names)) (lambda (y) (markup #:bold (psg-pitch-to-markup (list-ref strings y) #f)))))
         (colorproc (if (> x 0) (lambda (y) (if (> y 0) (if (= (modulo y 2) 1) color2 color1) headingcolor)) (lambda (y) (begin headingcolor)))))
        (psg-string-loop copedent size id listproc colorproc)))))

#(define-markup-command (psg-copedent-diagram layout props copedent size)
  (psg-copedent? number?)
  (let 
   ((width size) 
    (height (/ size 2))
    (textsize (- size 3)))
    (interpret-markup layout props
      #{
        \markup
        {
          \fontsize #textsize \override #`(word-space . ,(/ size 22)) \line #(psg-pedal-lever-loop copedent size  (rgb-color 0.7 0.7 0.7)  (rgb-color 0.88 0.88 0.88)  (rgb-color 0.95 0.95 0.95) #f)
        }
      #})))
  
%% Define the PedalSteelTab context

\layout
{
    \context
    {
      \TabStaff
      \name PedalSteelTab
      \alias TabStaff
      \consists #psg-tab-engraver
      
      psgTabInSpace = ##t
      psgClefStyle = #'both
    }
    
    \inherit-acceptability PedalSteelTab TabStaff
    
    \context
    {
      \Staff
      \omit StringNumber
      \name PedalSteelStaff
      \alias Staff

      \omit StringNumber
    }
    
    \inherit-acceptability PedalSteelStaff Staff
    \inherit-acceptability Staff PedalSteelStaff
    
}