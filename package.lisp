;; packages.lisp -  The package definition(s) for microblog-bot.
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

(defpackage microblog-bot
  (:documentation
   "Microblog bot creation support.")
  ;; We have to import usocket, drakma, and cl+ssl to handle their exceptions
  (:use #:common-lisp #:cl-twit #:usocket #:drakma #:cl+ssl)
  (:export set-microblog-service
	   set-debug
	   set-live
	   report-error

	   microblog-user
	   user-nickname
	   user-password
	   with-microblog-user

	   microblog-bot
	   filter-replies
	   queue-update
	   response-for-mention
	   response-for-source-request
	   response-for-post
	   response-p

	   constant-task-bot
	   constant-task
	   intermittent-task-bot
	   intermittent-task
	   daily-task-bot
	   daily-task

	   microblog-follower-bot
	   filter-posts

	   run-bot-once
	   run-bot
	   test-run-bot-once
	   test-run-bot))
