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
  (make-music 'PsgPedalOrLeverEvent 'span-direction span-dir 'psgID (psg-id-to-string id) 'amount amount))

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
    (let 
      ((current-alterations (cadar pedal-and-levers))
       (extended-alterations (caddar pedal-and-levers)))
      (if (and (= (length current-alterations) (length strings)) (or (null? extended-alterations)(= (length extended-alterations) (length strings))))
        (and (psg-check-alterations current-alterations) (psg-check-alterations extended-alterations) (psg-check-pedals-and-levers strings (cdr pedal-and-levers)))
        (ly:error ("Number of string alterations in pedal or lever doesn't match the number of strings!"))))))

#(define (psg-copedent? copedent)
  (if (and (not (null? copedent)) (list? copedent))
    (let 
      ((strings (car copedent))
       (pedals-and-levers (cdr copedent)))
      (and (psg-check-strings strings) (psg-check-pedals-and-levers strings pedals-and-levers)))
    (begin #f)))

%% Context properties

#(set-object-property! 'psgCopedent 'translation-type? psg-copedent?)
#(set-object-property! 'psgTabInSpace 'translation-type? boolean?)
#(set-object-property! 'psgClefStyle 'translation-type? symbol?)
#(set-object-property! 'psgID 'backend-type? string?)
#(set-object-property! 'psgAmount 'backend-type? number?)

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
    (let 
      ((pedals-and-levers (psg-copedent-pedals-and-levers copedent)))
       (cdr (list-ref pedals-and-levers (- (length pedals-and-levers) (length id-sublist)))))
    (begin #f)))

%% Evaluation of copedents - here we define functions for deftermining the active tuning given a copedent and set of active pedals or levers

#(define (naturalize-pitch p)
   (let 
      ((o (ly:pitch-octave p))
       (a (* 4 (ly:pitch-alteration p)))    
       (n (ly:pitch-notename p)))
      (cond
        ((and (> a 1) (or (eqv? n 6) (eqv? n 2)))
        (set! a (- a 2))
        (set! n (+ n 1)))
        ((and (< a -1) (or (eqv? n 0) (eqv? n 3)))
         (set! a (+ a 2))
         (set! n (- n 1))))
      (cond
        ((> a 2) (set! a (- a 4)) (set! n (+ n 1)))
        ((< a -2) (set! a (+ a 4)) (set! n (- n 1))))
      (if (< n 0) (begin (set! o (- o 1)) (set! n (+ n 7))))
      (if (> n 6) (begin (set! o (+ o 1)) (set! n (- n 7))))
      (let 
        ((np (ly:make-pitch o n (/ a 4))))
        (if (equal? np p)
          (begin p)
          (naturalize-pitch np)))))

#(define (transpose-string pitch alter)
  (if (= alter 0)
    (begin pitch)
    (naturalize-pitch (ly:make-pitch
      (ly:pitch-octave pitch)
      (ly:pitch-notename pitch)
      (+ (ly:pitch-alteration pitch) (/ alter 2))))))

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
    (let 
      ((alterations (psg-alterations-for-id copedent (caar active)))
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

%% Grobs and Interfaces

#(define (add-grob-definition grob-entry)
   (set! all-grob-descriptions
         (cons ((@@ (lily) completize-grob-entry) grob-entry) all-grob-descriptions)))

#(add-grob-definition `(PSGPedalOrLeverBracket
  . ((direction . ,DOWN)
     (edge-height . (0 . 0.8))
     (font-series . bold)
     (font-shape . upright)
     (minimum-length . 0.3)
     (outside-staff-priority . 400)
     (padding . 0.5)
     (shorten-pair . (0 . 0))
     (staff-padding . 2.0)
     (stencil . ,ly:ottava-bracket::print)
     (style . line)
     (thickness . 1)
     (vertical-skylines . ,grob::unpure-vertical-skylines-from-stencil)
     (Y-offset . ,side-position-interface::y-aligned-side)
     (meta . ((class . Spanner)
              (interfaces . (font-interface
                             horizontal-bracket-interface
                             line-interface
                             outside-staff-interface
                             psg-pedal-or-lever-interface
                             side-position-interface
                             text-interface))
              (description . "A pedal steel pedal or level bracket."))))))

#(add-grob-definition `(PSGPedalOrLeverBracketLineSpanner
  . ((axes . (,Y))
     (cross-staff . ,ly:side-position-interface::calc-cross-staff)
     (direction . ,DOWN)
     (minimum-space . 1.2)
     (outside-staff-priority . 250)
     (padding . 0.6)
     (side-axis . ,Y)
     (slur-padding . 0.3)
     (staff-padding . 0.1)
     (vertical-skylines
      . ,grob::always-vertical-skylines-from-element-stencils)
     (X-extent . ,ly:axis-group-interface::width)
     (Y-extent . ,axis-group-interface::height)
     (Y-offset . ,side-position-interface::y-aligned-side)
     (meta . ((class . Spanner)
              (object-callbacks
               . ((pure-Y-common . ,ly:axis-group-interface::calc-pure-y-common)
                  (pure-relevant-grobs . ,ly:axis-group-interface::calc-pure-relevant-grobs)))
              (interfaces . (axis-group-interface
                             psg-pedal-or-lever-interface
                             psg-pedal-or-lever-line-spanner-interface
                             outside-staff-interface
                             side-position-interface))
              (description . "An auxiliary grob providing a vertical baseline to align pedal or lever brackets."))))))


#(ly:add-interface
  'psg-pedal-or-lever-interface
  "A pedal steel guitar lever or bracket."
  '())

#(ly:add-interface
  'psg-pedal-or-lever-line-spanner-interface
  "Pedal steel guitar lever or bracket line spanner."
  '())

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

#(define (psg-id-find record id)
  (if (null? record)
    (begin #f)
    (if (equal? (caar record) id)
      (begin (cadar record))
      (psg-id-find (cdr record) id))))

#(define (psg-remove-id record id)
  (filter (lambda (x) (not (equal? (car x) id))) record))

#(define (psg-add-id record id data-object)
  (append record (list (list id data-object))))

#(define (psg-loop-and-clear record proc)
  (for-each proc record)
  (begin '()))
        
#(define (psg-make-change-markuplist id amount change)
  (let 
    ((markuplist (if change (list (markup #:simple "")) (list (markup #:simple id)))))
    (if (> amount 1)
      (begin
        (append! markuplist (list (markup #:simple "+")))
        (set! amount (- amount 1))))
    (if (not (integer? amount))
      (cond 
        ((= amount (/ 1 2)) (append! markuplist (list (markup #:simple "½"))))
        ((= amount (/ 1 3)) (append! markuplist (list (markup #:simple "⅓"))))
        ((= amount (/ 2 3)) (append! markuplist (list (markup #:simple "⅔"))))
        ((= amount (/ 1 4)) (append! markuplist (list (markup #:simple "¼"))))
        ((= amount (/ 3 4)) (append! markuplist (list (markup #:simple "¾"))))
        ((= amount (/ 1 5)) (append! markuplist (list (markup #:simple "⅕"))))
        ((= amount (/ 2 5)) (append! markuplist (list (markup #:simple "⅖"))))
        ((= amount (/ 3 5)) (append! markuplist (list (markup #:simple "⅗"))))
        ((= amount (/ 4 5)) (append! markuplist (list (markup #:simple "⅘"))))
        ((= amount (/ 1 6)) (append! markuplist (list (markup #:simple "⅙"))))
        ((= amount (/ 5 6)) (append! markuplist (list (markup #:simple "⅚"))))
        ((= amount (/ 1 8)) (append! markuplist (list (markup #:simple "⅛"))))
        ((= amount (/ 3 8)) (append! markuplist (list (markup #:simple "⅜"))))
        ((= amount (/ 5 8)) (append! markuplist (list (markup #:simple "⅝"))))
        ((= amount (/ 7 8)) (append! markuplist (list (markup #:simple "⅞"))))
        (else #f)))
    (begin markuplist)))

#(define (psg-make-bracket-grob context engraver id amount change event)   
  (let 
    ((grob (ly:engraver-make-grob engraver 'PSGPedalOrLeverBracket event))
     (column (ly:context-property context 'currentMusicalColumn)))
    (begin
      (ly:spanner-set-bound! grob LEFT column)
      (ly:grob-set-property! grob 'psgID id)
      (ly:grob-set-property! grob 'psgAmount amount)
      (ly:grob-set-property! grob 'text (markup (#:fontsize -4 (#:sans ( #:bold (make-concat-markup (psg-make-change-markuplist id amount change)))))))
      grob)))

#(define (psg-end-bracket-grob context grobs id change)
  (let 
    ((grob (psg-id-find grobs id))
     (column (ly:context-property context 'currentCommandColumn)))
    (ly:spanner-set-bound! grob RIGHT column)
    (if change
        (ly:grob-set-property! grob 'edge-height '(0 . 0)))
    (psg-remove-id grobs id)))

#(define (psg-tab-engraver context)
  (let
    ((copedent (ly:context-property context 'psgCopedent))
     (in-space (ly:context-property context 'psgTabInSpace))
     (clef-style (if (equal? (ly:context-property context 'psgClefStyle) 'both) 0 (if (equal? (ly:context-property context 'psgClefStyle) 'numbers) 1 2)))
     (active '())
     (changes '())
     (grobs '())
     (clefs '())
     (note-heads '()))
    (make-engraver
      ;; ------- initialize -------
      ((initialize engraver)
        (if (not (psg-copedent? copedent))
          (ly:error "Copedent is not defined for PSGTabStaff"))
        (ly:context-set-property! context 'stringTunings (psg-evaluate-copedent copedent active in-space)))
      ;; ------- listeners -------
      (listeners
        ((psg-pedal-or-lever-event engraver event)
          (define dir (ly:event-property event 'span-direction))
          (define id (ly:event-property event 'psgID))
          (define amount (ly:event-property event 'amount))
          (if (psg-valid-pedal-or-lever copedent id amount)
            (begin
              (if (eq? dir START)
                (if (not (psg-id-find active id))
                  (begin ;pedal/lever on
                    (set! active (psg-add-id active id amount))
                    (set! changes (psg-add-id changes id (list 1 amount event))))
                  (if (member (list id amount) active)
                    (ly:warning "Pedal or lever ~a re-engaged at the same amount without releasing/changing it" id)
                    (begin ;pedal/lever changed
                      (set! active (psg-add-id (psg-remove-id active id) id amount))
                      (set! changes (psg-add-id changes id (list 2 amount event))))))
                (if (psg-id-find active id)
                  (begin ;pedal/lever off
                    (set! active (psg-remove-id active id))
                    (set! changes (psg-add-id changes id (list 0 amount event))))
                  (ly:warning "Pedal or lever ~a released without engaging it" id)))
              (ly:context-set-property! context 'stringTunings (psg-evaluate-copedent copedent active in-space))))))
      ;; ------- acknowledgers -------
      (acknowledgers
        ((clef-interface engraver grob source-engraver)
          (set! clefs (cons grob clefs)))
        ((note-head-interface engraver grob source-engraver)
          (set! note-heads (cons grob note-heads))))
      ;; ------- process acknowledged -------
      ((process-acknowledged engraver)
        (set! clefs (psg-loop-and-clear clefs (lambda (clef)
            (ly:grob-set-property! clef 'stencil (psg-tab-clef-stencil copedent in-space clef-style)))))
        (if in-space
           (set! note-heads (psg-loop-and-clear note-heads (lambda (note-head)
              (ly:grob-set-property! note-head 'extra-offset '(0 . -0.5))
              (ly:grob-set-property! note-head 'font-size -3)
              (ly:grob-set-property! note-head 'whiteout #f))))))
      ;; ------- process music -------
      ((process-music engraver)
        (set! changes (psg-loop-and-clear changes (lambda (id-grob)                             
          (let 
            ((id (car id-grob))
             (type (caadr id-grob))
             (amount (cadadr id-grob))
             (event (car (cddadr id-grob))))
            (case type
              ((0) (set! grobs (psg-end-bracket-grob context grobs id #f)))
              ((1) (set! grobs (psg-add-id grobs id (psg-make-bracket-grob context engraver id amount #f event))))
              ((2) (set! grobs (psg-end-bracket-grob context grobs id #t )) (set! grobs (psg-add-id grobs id (psg-make-bracket-grob context engraver id amount #t event))))))))))
      ;; ------- finalize -------
      ((finalize engraver)
       (set! grobs (psg-loop-and-clear grobs (lambda (id-grob)                             
          (let 
            ((id (car id-grob)))
            (set! grobs (psg-end-bracket-grob context grobs id #f))))))))))

#(define (psg-make-alignment-grob context engraver idx)   
  (let 
    ((grob (ly:engraver-make-grob engraver 'PSGPedalOrLeverBracketLineSpanner '()))
     (column (ly:context-property context 'currentCommandColumn)))
    (begin 
      (ly:grob-set-property! grob 'outside-staff-priority (+ 250 (* 10 idx)))
      (ly:spanner-set-bound! grob LEFT column)
      grob)))

#(define (psg-end-alignment-grob context grob)
  (let 
    ((column (ly:context-property context 'currentCommandColumn)))
    (ly:spanner-set-bound! grob RIGHT column)))

#(define (psg-tab-alignment-engraver context)
  (let
    ((copedent (ly:context-property context 'psgCopedent))
     (new-grobs '())
     (alignment-grobs '()))
    (make-engraver
      ;; ------- acknowledgers -------
      (acknowledgers
        ((psg-pedal-or-lever-interface engraver grob source-engraver)
          (set! new-grobs (cons grob new-grobs))))
      ;; ------- process acknowledged -------
      ((process-acknowledged engraver)
        (set! new-grobs (psg-loop-and-clear new-grobs (lambda (grob)
          (let
            ((id (ly:grob-property grob 'psgID)))
            (ly:grob-set-property! grob 'Y-offset -2)
            (ly:axis-group-interface::add-element (psg-id-find alignment-grobs id) grob))))))
      ;; ------- process-music -------
      ((process-music engraver)   
       (when (and (null? alignment-grobs) (not (null? (psg-copedent-id-list copedent))))
         (for-each (lambda (id idx) 
          (set! alignment-grobs (psg-add-id alignment-grobs id (psg-make-alignment-grob context engraver idx)))) (psg-copedent-id-list copedent) (iota (length (psg-copedent-id-list copedent))))))
      ;; ------- finalize -------
      ((finalize engraver)
        (let 
          ((column (ly:context-property context 'currentCommandColumn)))
          (set! alignment-grobs (psg-loop-and-clear alignment-grobs (lambda (id-grob)                             
            (psg-end-alignment-grob context (cadr id-grob))))))))))
              
%% Markup for copedents

#(define (psg-markuplist-loop idx to proc)
  (if (>= idx to)
    (list (proc idx))
    (append (list (proc idx)) (psg-markuplist-loop (+ idx 1) to proc))))

#(define (psg-pitch-to-markup pitch whiteout)
  (let 
    ((alteration (ly:pitch-alteration pitch))
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
  (let 
    ((width size) 
     (height (/ size 2.5)) 
     (thickness (/ size 80)))
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
          \fontsize #textsize \override #`(word-space . ,(/ size 22)) \line #(psg-pedal-lever-loop copedent size  (rgb-color 0.7 0.7 0.7)  (rgb-color 0.88 0.88 0.88)  (rgb-color 0.95 0.95 0.95) #t)
        }
      #})))
  
%% Define the PedalSteelTab context

\layout
{
  \context
  {
    \Global
    \grobdescriptions #all-grob-descriptions
  }

  \context
  {
    \TabStaff
    \name PedalSteelTab
    \alias TabStaff
    \consists #psg-tab-engraver
    \consists #psg-tab-alignment-engraver
      
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