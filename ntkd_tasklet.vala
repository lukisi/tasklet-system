/*
 *  This file is part of Netsukuku.
 *  (c) Copyright 2015 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */
using Gee;

namespace Netsukuku
{
    public interface INtkdTaskletSpawnable : Object
    {
        public abstract void * func();
    }

    public interface INtkdTaskletHandle : Object
    {
        public abstract bool is_running();
        public abstract void kill();
        public abstract bool is_joinable();
        public abstract void * join();
    }

    public interface INtkdServerStreamSocket : Object
    {
        public abstract INtkdConnectedStreamSocket accept() throws Error;
        public abstract void close() throws Error;
    }

    public interface INtkdConnectedStreamSocket : Object
    {
        public string peer_address {
            get {
                return _peer_address_getter();
            }
        }
        public abstract unowned string _peer_address_getter();
        public string my_address {
            get {
                return _my_address_getter();
            }
        }
        public abstract unowned string _my_address_getter();
        public abstract size_t recv(uint8* b, size_t maxlen) throws Error;
        public abstract void send(uint8* b, size_t len) throws Error;
        public abstract void close() throws Error;
    }

    public interface INtkdServerDatagramSocket : Object
    {
        public abstract size_t recvfrom(uint8* b, size_t maxlen, out string rmt_ip, out uint16 rmt_port) throws Error;
        public abstract void close() throws Error;
    }

    public interface INtkdClientDatagramSocket : Object
    {
        public abstract size_t sendto(uint8* b, size_t len) throws Error;
        public abstract void close() throws Error;
    }

    public class NtkdTaskletCommandResult : Object
    {
        public string stdout;
        public string stderr;
        public int exit_status;
    }

    public errordomain NtkdChannelError
    {
        TIMEOUT
    }

    public interface INtkdChannel : Object
    {
        public abstract void send(Value v);
        public abstract void send_async(Value v);
        public abstract int get_balance();
        public abstract Value recv();
        public abstract Value recv_with_timeout(int timeout_msec) throws NtkdChannelError;
    }

    public interface INtkdTasklet : Object
    {
        public abstract void schedule();
        public abstract void ms_wait(int msec);
        [NoReturn]
        public abstract void exit_tasklet(void * ret);
        public abstract INtkdTaskletHandle spawn(INtkdTaskletSpawnable sp, bool joinable=false);
        public abstract NtkdTaskletCommandResult exec_command(string cmdline) throws Error;
        public abstract INtkdServerStreamSocket get_server_stream_socket(uint16 port, string? my_addr=null) throws Error;
        public abstract INtkdConnectedStreamSocket get_client_stream_socket(string dest_addr, uint16 dest_port, string? my_addr=null) throws Error;
        public abstract INtkdServerDatagramSocket get_server_datagram_socket(uint16 port, string dev) throws Error;
        public abstract INtkdClientDatagramSocket get_client_datagram_socket(uint16 port, string dev) throws Error;
        public abstract INtkdChannel get_channel();
        public NtkdDispatchableTasklet create_dispatchable_tasklet() {return new NtkdDispatchableTasklet(this);}
    }

    public class NtkdDispatchableTasklet
    {
        private class DispatchedTasklet : Object
        {
            public INtkdChannel ch;
            public INtkdTaskletSpawnable sp;
        }
        private class DispatcherTasklet : Object, INtkdTaskletSpawnable
        {
            public NtkdDispatchableTasklet dsp;
            public void * func()
            {
                while (dsp.lst_sp.size > 0)
                {
                    DispatchedTasklet x = dsp.lst_sp.remove_at(0);
                    x.sp.func();
                    if (x.ch.get_balance() < 0) x.ch.send_async(0);
                }
                return null;
            }
        }
        private INtkdTaskletHandle? t;
        private ArrayList<DispatchedTasklet> lst_sp;
        private INtkdTasklet tasklet;
        internal NtkdDispatchableTasklet(INtkdTasklet tasklet)
        {
            this.tasklet = tasklet;
            t = null;
            lst_sp = new ArrayList<DispatchedTasklet>();
        }
        public void dispatch(INtkdTaskletSpawnable sp, bool wait=false)
        {
            DispatchedTasklet dt = new DispatchedTasklet();
            dt.ch = tasklet.get_channel();
            dt.sp = sp;
            lst_sp.add(dt);
            if (t == null || !t.is_running())
            {
                DispatcherTasklet ts = new DispatcherTasklet();
                ts.dsp = this;
                t = tasklet.spawn(ts);
            }
            if (wait)
            {
                dt.ch.recv();
            }
        }
        public bool is_empty()
        {
            return t == null || !t.is_running();
        }
    }
}

