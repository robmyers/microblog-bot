;; microblog-bot.lisp - Basic bot for microblogging (Twitter, Laconica).
;; Copyright (C) 2009, 2010  Rob Myers rob@robmyers.org
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.
;;
;; You should have received a copy of the GNU Affero General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Package
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package :microblog-bot)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Basic bot
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconstant %sleep-time 180
  "How many seconds to wait between each run of the bot")

(defconstant %default-source-url nil
  "The default source url for this code (or a derivative)")
(defconstant %default-last-handled-reply 0
  "The default last reply post id handled")
(defconstant %default-ignore-replies-from '()
  "Usernames to ignore replies from")

(defclass microblog-bot (microblog-user)
  ((source-url :accessor source-url
	       :initarg :source-url
	       :allocation :class
	       :initform %default-source-url)
   (ignore-replies-from :accessor ignore-replies-from
			 :initarg :ignore
			 :initform %default-ignore-replies-from)
   (last-handled-reply :accessor last-handled-reply 
			:initarg :last-handled-reply 
			:initform %default-last-handled-reply)
   (updates-to-post :accessor updates-to-post
		    :initform '())
   (update-timespan :accessor update-timespan
		    :initarg :update-timespan
		    ;; Spread the responses over 20 minutes
		    :initform (* 20 60))))

(defmethod last-handled-reply-id ((bot microblog-bot))
  "Get the exclusive lower bound for replies to the user to check"
  (or (cl-twit::get-newest-id (cl-twit:m-user-timeline))
      (cl-twit::get-newest-id (cl-twit:m-public-timeline))))

(defmethod initialize-instance :after ((bot microblog-bot) &key)
  "Set up the bot's state"
  (assert (source-url bot))
  (handler-case 
      (with-microblog-user bot    
	(setf (last-handled-reply bot)
	      (last-handled-reply-id bot)))
    (condition (the-condition) 
      (format t "Error for ~a ~%" (user-nickname bot))
      (invoke-debugger the-condition)))
  (debug-msg "Initialized bot ~a most-recent-reply ~a" 
	     bot (last-handled-reply bot)))

(defmethod response-for-source-request ((bot microblog-bot) reply)
  "Response for the source request"
  (format nil "@~a Hi! You can get my source here: ~a" 
	  (cl-twit:user-screen-name 
	   (cl-twit:status-user reply))
	  (source-url bot)))

(defmethod response-for-reply ((bot microblog-bot) reply)
  "Response for the reply object"
  (format nil "@~a Hi!" 
	  (cl-twit:user-screen-name 
	   (cl-twit:status-user reply))))

(defmethod response-p ((bot microblog-bot) post)
  "Check whether our post is a response."
  (search "Hi!" (cl-twit:status-text post)))

(defmethod filter-replies ((bot microblog-bot) replies)
  "Make sure only one reply from each user is listed"
  (remove-duplicates replies 
		     :test #'(lambda (a b)
			       (string=
				(cl-twit:user-screen-name 
				 (cl-twit:status-user a))
				(cl-twit:user-screen-name 
				 (cl-twit:status-user b))))))

(defmethod should-ignore ((bot microblog-bot) message &optional (default t))
  "Check whether the bot should ignore the message"
  (handler-case
      (find (cl-twit:user-screen-name
	     (cl-twit:status-user message))
	    (ignore-replies-from bot)
	    :test #'string=)
    (condition (the-condition) 
      (report-error "should-ignore ~a ~a - ~a~%" 
		    (user-nickname bot) bot the-condition)
      default)))

(defmethod new-replies ((bot microblog-bot))
  "Get any new replies for the bot's account, or nil"
  (debug-msg "new-replies after ~a" (last-handled-reply bot))
  (handler-case
      (sort (cl-twit:m-replies :since-id 
			       (last-handled-reply bot))
	    #'string< :key #'cl-twit::id)
    (condition (the-condition)
      (report-error "new-replies ~a ~a - ~a~%"
		    (user-nickname bot) bot the-condition)
      nil)))

(defun source-request-p (reply)
  "Is the message a source request?"
  (search "!source" (cl-twit:status-text reply)))

(defmethod respond-to-replies ((bot microblog-bot))
  "Respond to new replies since replies were last processed"
  ;; If we've ended up with a null last-handled-reply, try to recover
  (when (not (last-handled-reply bot))
    (setf (last-handled-reply bot)
	  (last-handled-reply-id bot)))
  ;; If it's still null the server is probably sad, don't respond this time
  (when (last-handled-reply bot)
    (let ((replies (filter-replies bot (new-replies bot))))
      (when replies 
	(dolist (reply replies)
	  (when (not (should-ignore bot reply t))
	    (handler-case
	     (let ((response (if (source-request-p reply)
				 (response-for-source-request bot reply)
			       (response-for-reply bot reply))))
	       (when response
		 (queue-update bot response
		       :in-reply-to (cl-twit::status-id reply))))
	     (condition (the-condition)
		    (report-error "respond-to-replies ~a ~a - ~a~%" 
				  (user-nickname bot) bot the-condition)))))
	;; If any responses failed, they will be skipped
	;; This will set to null if replies are null, so ensure it's in a when 
	(setf (last-handled-reply bot)
	      (cl-twit::get-newest-id replies))))))

(defmethod manage-task ((bot microblog-bot))
  "Do the bot's task once."
  (respond-to-replies bot))

(defmethod queue-update ((bot microblog-bot) (update string) &key 
			 (in-reply-to nil))
  "Queue the update to be posted as soon as possible."
  ;; Store as (message . in-reply-to-message-id), the latter probably nil
  (setf  (updates-to-post bot)  
	 (append (updates-to-post bot) (list (cons update in-reply-to)))))

(defmethod post-updates ((bot microblog-bot))
  "Post the updates"
  (let* ((updates-count (length (updates-to-post bot)))
	 (time-between-updates (floor (/ (update-timespan bot)
					 (max updates-count 1)))))
    ;; Loop, taking updates from the list
    (loop 
       for update = (pop (updates-to-post bot))
       then (pop (updates-to-post bot))
       while update
       ;; Posting them
       ;; This is the one place in the code we actually want to use (post)
       do (handler-case 
	   (progn (post (car update) :in-reply-to-status-id (cdr update))
		  ;; More to post? Sleep before doing so
		  (if (updates-to-post bot)
		      (sleep time-between-updates)))
	    (cl-twit:http-error (the-error)
	      (format t "Error for ~a ~a update \"~a\" - ~a ~%" 
		      (user-nickname bot) bot update the-error)
	      ;;FIXME: check (cl-twit:http-status-code the-error)
	      ;; and die on 4xx errors
	      ;; Restore the failed update
	      (push update (updates-to-post bot))
	      ;; And don't try any more for now, wait for the next run
	      ;; Which may not add any more messages, but will try to post these
	      (return))
	    ;; Other errors that we know about
	    ((or usocket:socket-condition usocket:ns-condition
	      drakma:drakma-condition cl+ssl::ssl-error)
		(the-error)
	      (format t "Error for ~a ~a update \"~a\" - ~a ~%" 
		      (user-nickname bot) bot update the-error)
	     ;; Restore the failed update
	     (push update (updates-to-post bot))
	     ;; And don't try any more for now, wait for the next run
	     ;; Which may not add any more messages, but will try to post these
	     (return))))))

(defmethod run-bot-once ((bot microblog-bot))
  (debug-msg "Running bot once ~a" bot)
  (handler-case
      (with-microblog-user bot
	;; The use of :after methods ensures that this handles all subclasses	
	(manage-task bot)
	;; This will try to post all the updates in the queue
	(post-updates bot))
    (condition (the-condition) 
      (format t "Error for ~a ~a - ~a ~%" (user-nickname bot) bot the-condition)
      ;; If the error wasn't handled it's unexpected, so quit here
      (invoke-debugger the-condition))))

(defmethod run-bot ((bot microblog-bot))
  "Loop forever responding to replies & occasionaly performing periodic-task"
  (loop 
     (run-bot-once bot)
     (sleep %sleep-time)))
