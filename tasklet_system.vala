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

namespace TaskletSystem
{
    public interface ITaskletSpawnable : Object
    {
        public abstract void * func();
    }

    public interface ITaskletHandle : Object
    {
        public abstract bool is_running();
        public abstract void kill();
        public abstract bool is_joinable();
        public abstract void * join();
    }

    public interface IServerStreamSocket : Object
    {
        public abstract IConnectedStreamSocket accept() throws Error;
        public abstract void close() throws Error;
    }

    public interface IConnectedStreamSocket : Object
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

    public interface IServerDatagramSocket : Object
    {
        public abstract size_t recvfrom(uint8* b, size_t maxlen, out string rmt_ip, out uint16 rmt_port) throws Error;
        public abstract void close() throws Error;
    }

    public interface IClientDatagramSocket : Object
    {
        public abstract size_t sendto(uint8* b, size_t len) throws Error;
        public abstract void close() throws Error;
    }

    public class TaskletCommandResult : Object
    {
        public string stdout;
        public string stderr;
        public int exit_status;
    }

    public errordomain ChannelError
    {
        TIMEOUT
    }

    public interface IChannel : Object
    {
        public abstract void send(Value v);
        public abstract void send_async(Value v);
        public abstract int get_balance();
        public abstract Value recv();
        public abstract Value recv_with_timeout(int timeout_msec) throws ChannelError;
    }

    public interface ITasklet : Object
    {
        public abstract void schedule();
        public abstract void ms_wait(int msec);
        [NoReturn]
        public abstract void exit_tasklet(void * ret);
        public abstract ITaskletHandle spawn(ITaskletSpawnable sp, bool joinable=false);

        public abstract TaskletCommandResult exec_command_argv(Gee.List<string> argv) throws Error;
        public TaskletCommandResult exec_command(string cmdline) throws Error
        {
            ArrayList<string> argv = new ArrayList<string>();
            argv.add_all_array(cmdline.split(" "));
            return exec_command_argv(argv);
        }

        public abstract size_t read(int fd, void* b, size_t maxlen) throws Error;
        public abstract size_t write(int fd, void* b, size_t count) throws Error;
        public abstract IServerStreamSocket get_server_stream_socket(uint16 port, string? my_addr=null) throws Error;
        public abstract IConnectedStreamSocket get_client_stream_socket(string dest_addr, uint16 dest_port, string? my_addr=null) throws Error;
        public abstract IServerDatagramSocket get_server_datagram_socket(uint16 port, string dev) throws Error;
        public abstract IClientDatagramSocket get_client_datagram_socket(uint16 port, string dev, string? my_addr=null) throws Error;
        public abstract IChannel get_channel();
        public DispatchableTasklet create_dispatchable_tasklet() {return new DispatchableTasklet(this);}
    }

    public class DispatchableTasklet
    {
        private class DispatchedTasklet : Object
        {
            public IChannel ch_end;
            public IChannel ch_start;
            public ITaskletSpawnable sp;
            public DispatchedTasklet(ITaskletSpawnable sp, IChannel ch_end, IChannel ch_start)
            {
                this.ch_end = ch_end;
                this.ch_start = ch_start;
                this.sp = sp;
            }
        }
        private class DispatcherTasklet : Object, ITaskletSpawnable
        {
            public DispatchableTasklet dsp;
            public void * func()
            {
                while (dsp.lst_sp.size > 0)
                {
                    DispatchedTasklet x = dsp.lst_sp.remove_at(0);
                    if (x.ch_start.get_balance() < 0) x.ch_start.send_async(0);
                    x.sp.func();
                    if (x.ch_end.get_balance() < 0) x.ch_end.send_async(0);
                }
                return null;
            }
        }
        private ITaskletHandle? t;
        private ArrayList<DispatchedTasklet> lst_sp;
        private ITasklet tasklet;
        internal DispatchableTasklet(ITasklet tasklet)
        {
            this.tasklet = tasklet;
            t = null;
            lst_sp = new ArrayList<DispatchedTasklet>();
        }
        public void dispatch(ITaskletSpawnable sp, bool wait_end=false, bool wait_start=false)
        {
            DispatchedTasklet dt = new DispatchedTasklet(sp, tasklet.get_channel(), tasklet.get_channel());
            lst_sp.add(dt);
            if (t == null || !t.is_running())
            {
                DispatcherTasklet ts = new DispatcherTasklet();
                ts.dsp = this;
                t = tasklet.spawn(ts);
            }
            if (wait_end)
            {
                dt.ch_end.recv();
            }
            else if (wait_start)
            {
                dt.ch_start.recv();
            }
        }
        public bool is_empty()
        {
            return t == null || !t.is_running();
        }
    }
}

